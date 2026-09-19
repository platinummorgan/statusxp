import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/flex_room_repository.dart';

void main() {
  test(
    'picker requests bounded ordered RPC pages and preserves search filters',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = FlexRoomRepository(client);
      await repository.getGamesForPlatform(
        'owner',
        'psn',
        searchQuery: 'Game',
        page: 2,
      );
      expect(requests.length, 4);
      for (final request in requests) {
        expect(request.url.queryParameters['offset'], '60');
        expect(request.url.queryParameters['limit'], '30');
        expect(
          request.url.queryParameters['order'],
          'game_name.asc.nullslast,platform_game_id.asc.nullslast',
        );
        expect(jsonDecode(request.body)['p_search_query'], 'Game');
      }
      requests.clear();
      await repository.getAchievementsForGame(
        'owner',
        'game',
        'steam',
        platformId: 4,
        platformGameId: 'game',
        searchQuery: 'Unlock',
        page: 1,
      );
      expect(requests.length, 1);
      expect(requests.single.url.queryParameters['offset'], '30');
      expect(requests.single.url.queryParameters['limit'], '30');
      expect(
        requests.single.url.queryParameters['order'],
        'achievement_name.asc.nullslast,platform_achievement_id.asc.nullslast',
      );
      expect(jsonDecode(requests.single.body)['p_platform_game_id'], 'game');
      expect(jsonDecode(requests.single.body)['p_search_query'], 'Unlock');
    },
  );
}
