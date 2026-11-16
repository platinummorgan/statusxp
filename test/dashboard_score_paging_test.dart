import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:statusxp/data/repositories/supabase_dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient dashboardClient(
  Future<http.Response> Function(http.Request) scoreResponse,
) => SupabaseClient(
  'https://test.invalid',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/rpc/calculate_statusxp_with_stacks')) {
      return scoreResponse(request);
    }
    final body = switch (request.url.path.split('/').last) {
      'profiles' => {'psn_online_id': 'Player'},
      'leaderboard_cache' => {'total_statusxp': 12345},
      'psn_leaderboard_cache' => {'platinum_count': 1, 'total_games': 1000},
      'xbox_leaderboard_cache' => {'gamerscore': 10, 'total_games': 100},
      'steam_leaderboard_cache' => {'total_games': 100},
      _ => throw StateError('Unexpected dashboard request ${request.url.path}'),
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

void main() {
  for (final gameCount in [1000, 1200]) {
    test(
      'dashboard includes every score in a $gameCount game library',
      () async {
        final requests = <http.Request>[];
        final client = dashboardClient((request) async {
          requests.add(request);
          final offset = int.parse(request.url.queryParameters['offset']!);
          final remaining = gameCount - offset;
          final count = remaining.clamp(0, 1000);
          return http.Response(
            jsonEncode(
              List.generate(count, (index) {
                final game = offset + index;
                return {
                  'platform_id': game < 1000 ? 1 : (game < 1100 ? 10 : 4),
                  'platform_game_id': 'game-$game',
                  'statusxp_effective': game < 1000 ? 2 : (game < 1100 ? 3 : 4),
                };
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });
        addTearDown(client.dispose);

        final stats = await SupabaseDashboardRepository(
          client,
        ).getDashboardStats('owner');
        for (final request in requests) {
          expect(jsonDecode(request.body)['p_user_id'], 'owner');
          expect(request.url.queryParameters['limit'], '1000');
          expect(
            request.url.queryParameters['order'],
            'platform_id.asc.nullslast,platform_game_id.asc.nullslast',
          );
        }
        expect(requests.length, 2);
        expect(stats.totalStatusXP, gameCount == 1000 ? 2000 : 2700);
        expect(stats.psnStats.statusXP, 2000);
        expect(stats.xboxStats.statusXP, gameCount == 1000 ? 0 : 300);
        expect(stats.steamStats.statusXP, gameCount == 1000 ? 0 : 400);
      },
    );
  }

  test(
    'later page failure uses the cache instead of a partial total',
    () async {
      final client = dashboardClient((request) async {
        final offset = int.parse(request.url.queryParameters['offset']!);
        if (offset > 0) {
          return http.Response(
            '{"code":"57014","message":"Timed out"}',
            500,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode(
            List.generate(
              1000,
              (index) => {
                'platform_id': 1,
                'platform_game_id': 'game-$index',
                'statusxp_effective': 2,
              },
            ),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      addTearDown(client.dispose);

      final stats = await SupabaseDashboardRepository(
        client,
      ).getDashboardStats('owner');
      expect(stats.totalStatusXP, 12345);
      expect(stats.psnStats.statusXP, 0);
    },
  );
}
