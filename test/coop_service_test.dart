import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/trophy_help_service.dart';

void main() {
  test(
    'discovery applies search and platform before bounded deterministic pagination',
    () async {
      http.Request? request;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          request = r;
          return http.Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await TrophyHelpService(client).getCoopPage(
        feed: CoopFeed.discover,
        platform: 'xbox',
        search: 'Halo, "100%"',
        offset: 24,
      );
      final q = request!.url.queryParameters;
      expect(q['status'], 'eq.open');
      expect(q['platform'], 'eq.xbox');
      expect(q['offset'], '24');
      expect(q['limit'], '24');
      expect(q['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(q['or'], contains('game_title.ilike."%Halo,'));
      expect(q['or'], contains('achievement_name.ilike.'));
      expect(q['or'], contains(r'\"100\\%\"'));
    },
  );
  test('query failures propagate and retry makes a new request', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://test.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        calls++;
        return http.Response(
          calls == 1 ? '{"message":"offline"}' : '[]',
          calls == 1 ? 400 : 200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final service = TrophyHelpService(client);
    await expectLater(
      service.getCoopPage(feed: CoopFeed.discover),
      throwsA(isA<PostgrestException>()),
    );
    expect(await service.getCoopPage(feed: CoopFeed.discover), isEmpty);
    expect(calls, 2);
    await expectLater(
      service.getCoopPage(feed: CoopFeed.discover, limit: 100),
      throwsArgumentError,
    );
    expect(calls, 2);
  });
  test(
    'own offers query retains offer status and filters embedded requests',
    () async {
      http.Request? request;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          request = r;
          return http.Response(
            jsonEncode([
              {
                'status': 'accepted',
                'request': {
                  'id': 'request',
                  'profile_id': 'owner',
                  'game_id': 'game',
                  'game_title': 'Game',
                  'achievement_id': 'achievement',
                  'achievement_name': 'Goal',
                  'platform': 'steam',
                  'status': 'assigned',
                  'created_at': '2026-01-01T00:00:00Z',
                  'updated_at': '2026-01-01T00:00:00Z',
                },
              },
            ]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'fixture',
          'refresh_token': 'fixture',
          'token_type': 'bearer',
          'expires_at':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'user': {
            'id': 'helper',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      final rows = await TrophyHelpService(
        client,
      ).getCoopPage(feed: CoopFeed.offers, platform: 'steam', search: 'Goal');
      expect(rows.single.offerStatus, 'accepted');
      expect(rows.single.request.status, 'assigned');
      final q = request!.url.queryParameters;
      expect(q['helper_profile_id'], 'eq.helper');
      expect(q['request.platform'], 'eq.steam');
      expect(q['request.or'], contains('achievement_name.ilike.'));
      expect(q['select'], contains('!inner'));
    },
  );
}
