import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/ui/widgets/game_catalog_summary.dart';

void main() {
  test(
    'catalog totals include later pages and bind both game identifiers',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['platform_id'], 'eq.4');
          expect(request.url.queryParameters['platform_game_id'], 'eq.game');
          expect(
            request.url.queryParameters['offset'],
            calls == 0 ? '0' : '500',
          );
          final rows = calls++ == 0
              ? List.generate(
                  500,
                  (i) => {
                    'platform_achievement_id': '$i',
                    'base_status_xp': 10,
                  },
                )
              : [
                  {'platform_achievement_id': 'last', 'base_status_xp': 23},
                ];
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final totals = await loadGameCatalogTotals(
        client,
        const GameRef(platformId: 4, platformGameId: 'game'),
      );
      expect(totals.achievements, 501);
      expect(totals.baseXp, 5023);
      expect(calls, 2);
    },
  );

  test('missing point values do not become a misleading total', () async {
    final client = SupabaseClient(
      'https://test.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '[{"platform_achievement_id":"a","base_status_xp":null}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    final totals = await loadGameCatalogTotals(
      client,
      const GameRef(platformId: 4, platformGameId: 'game'),
    );
    expect(totals.achievements, 1);
    expect(totals.baseXp, isNull);
  });
}
