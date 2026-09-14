import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/flex_tile_loader.dart';
import 'package:statusxp/data/repositories/flex_room_repository.dart';
import 'package:statusxp/domain/flex_room_data.dart';

Map<String, dynamic> earned(int id, {int platform = 1}) => {
  'platform_id': platform,
  'platform_game_id': 'game',
  'platform_achievement_id': '$id',
  'earned_at': '2026-09-01T00:00:00Z',
};
http.Response response(
  Object? data,
  http.Request request, [
  int status = 200,
]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
  request: request,
);

void main() {
  test(
    'automatic persistence preserves saved keys even when hydration was unavailable',
    () async {
      Map<String, dynamic>? written;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') {
            written = jsonDecode(r.body) as Map<String, dynamic>;
            return response(null, r);
          }
          return response(written, r);
        }),
      );
      addTearDown(client.dispose);
      final original = {
        'flex_of_all_time_platform_id': 4,
        'flex_of_all_time_platform_game_id': 'saved-game',
        'flex_of_all_time_platform_achievement_id': 'saved-achievement',
        'superlatives': {
          'hardest': {
            'platform_id': 4,
            'platform_game_id': 'saved-game',
            'platform_achievement_id': 'saved-achievement',
          },
        },
      };
      final success = await FlexRoomRepository(client).updateFlexRoomData(
        FlexRoomData(userId: 'owner', lastUpdated: DateTime.utc(2026, 9, 13)),
        existingConfiguration: original,
      );
      expect(success, true);
      for (final entry in original.entries) {
        expect(written?[entry.key], entry.value);
      }
    },
  );
  test(
    '16 tiles plus duplicates use three requests and retain composite identities',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((r) async {
          calls.add(r);
          if (r.url.path.endsWith('/user_achievements')) {
            return response([for (var i = 0; i < 16; i++) earned(i)], r);
          }
          if (r.url.path.endsWith('/achievements')) {
            return response([
              for (var i = 0; i < 16; i++)
                {...earned(i), 'name': 'Achievement $i'},
            ], r);
          }
          return response([
            {
              'platform_id': 1,
              'platform_game_id': 'game',
              'name': 'Game',
              'cover_url': null,
            },
          ], r);
        }),
      );
      addTearDown(client.dispose);
      final loader = FlexTileLoader(client);
      final rows = await Future.wait([
        for (var i = 0; i < 32; i++)
          loader.load((
            user: 'owner',
            platform: 1,
            game: 'game',
            achievement: '${i % 16}',
          )),
      ]);
      expect(calls.length, 3);
      expect(calls.first.url.queryParameters['user_id'], 'eq.owner');
      expect(rows[15]?['achievement_name'], 'Achievement 15');
      expect(rows[31], rows[15]);
      await loader.load((
        user: 'owner',
        platform: 1,
        game: 'game',
        achievement: '0',
      ));
      expect(
        calls.length,
        6,
        reason: 'Completed loads must not retain stale tiles',
      );
    },
  );
  test(
    'unearned tiles are not hydrated and different users never share ownership results',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((r) async {
          calls.add(r);
          return response([], r);
        }),
      );
      addTearDown(client.dispose);
      final loader = FlexTileLoader(client);
      expect(
        await Future.wait([
          for (final u in ['A', 'B'])
            loader.load((user: u, platform: 1, game: 'game', achievement: '0')),
        ]),
        [null, null],
      );
      expect(calls.length, 2);
      expect(calls.map((r) => r.url.queryParameters['user_id']), [
        'eq.A',
        'eq.B',
      ]);
    },
  );
  test(
    'failed batches can retry and special characters remain quoted filter values',
    () async {
      var fail = true;
      String? filter;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((r) async {
          filter = r.url.queryParameters['or'];
          return fail
              ? response({'message': 'Unavailable', 'code': 'XX000'}, r, 500)
              : response([], r);
        }),
      );
      addTearDown(client.dispose);
      final loader = FlexTileLoader(client);
      const key = (user: 'A', platform: 4, game: 'a,b"c', achievement: '0');
      await expectLater(loader.load(key), throwsA(isA<PostgrestException>()));
      fail = false;
      expect(await loader.load(key), isNull);
      expect(filter, contains('platform_game_id.eq."a,b\\"c"'));
    },
  );

  for (final emptyConfig in [false, true]) {
    test(
      '${emptyConfig ? 'Saved empty' : 'New'} room automatically fills from earned achievements',
      () async {
        final calls = <http.Request>[];
        final tile = {
          ...earned(0),
          'achievement_name': 'First unlock',
          'game_name': 'Game',
          'rarity_global': 1.0,
        };
        final client = SupabaseClient(
          'https://test.invalid',
          'test',
          httpClient: MockClient((r) async {
            calls.add(r);
            final path = r.url.path;
            if (path.endsWith('/flex_room_data')) {
              return response(
                emptyConfig
                    ? {
                        'superlatives': {},
                        'last_updated': '2026-09-01T00:00:00Z',
                      }
                    : null,
                r,
              );
            }
            if (path.endsWith('/get_superlative_suggestions_v3')) {
              return response([earned(0)], r);
            }
            if (path.endsWith('/get_recent_notable_achievements_v2')) {
              return response([], r);
            }
            if (path.contains('/rpc/')) return response(tile, r);
            if (path.endsWith('/user_achievements')) {
              return response([earned(0)], r);
            }
            if (path.endsWith('/achievements')) {
              return response([
                {...earned(0), 'name': 'First unlock', 'rarity_global': 1.0},
              ], r);
            }
            if (path.endsWith('/games')) {
              return response([
                {'platform_id': 1, 'platform_game_id': 'game', 'name': 'Game'},
              ], r);
            }
            throw StateError(path);
          }),
        );
        addTearDown(client.dispose);
        final room = await FlexRoomRepository(
          client,
        ).getFlexRoomData('owner', includeRecent: false);
        expect(
          calls.where(
            (r) => r.url.path.endsWith('/get_recent_notable_achievements_v2'),
          ),
          isEmpty,
        );
        expect(room?.flexOfAllTime?.achievementName, 'First unlock');
        expect(room?.superlatives.length, 12);
        expect(
          calls.where((r) => r.url.path.endsWith('/user_achievements')).length,
          1,
        );
        expect(
          calls.where(
            (r) => r.method != 'GET' && !r.url.path.contains('/rpc/'),
          ),
          isEmpty,
          reason: 'Viewing someone else must not write defaults',
        );
      },
    );
  }
  test(
    'a user with no earned achievements receives an empty room without fabricated highlights',
    () async {
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        httpClient: MockClient((r) async {
          return response(
            r.url.path.endsWith('/flex_room_data') ||
                    r.url.path.contains('get_rarest_') ||
                    r.url.path.contains('get_most_time_') ||
                    r.url.path.contains('get_sweatiest_')
                ? null
                : [],
            r,
          );
        }),
      );
      addTearDown(client.dispose);
      final room = await FlexRoomRepository(client).getFlexRoomData('owner');
      expect(room?.flexOfAllTime, isNull);
      expect(room?.superlatives, isEmpty);
    },
  );
}
