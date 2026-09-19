import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/basic_library.dart';
import 'package:statusxp/ui/screens/unified_games_list_screen.dart';

void main() {
  test(
    'basic library fetches later pages and binds the signed-in user',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/user_progress');
          expect(request.url.queryParameters['user_id'], 'eq.owner');
          expect(
            request.url.queryParameters['order'],
            'platform_id.asc.nullslast,platform_game_id.asc.nullslast',
          );
          expect(
            request.url.queryParameters['offset'],
            calls == 0 ? '0' : '500',
          );
          final rows = calls++ == 0
              ? List.generate(
                  500,
                  (i) => {
                    'platform_id': 4,
                    'platform_game_id': '$i',
                    'games': {'name': 'Game $i'},
                  },
                )
              : [
                  {
                    'platform_id': 4,
                    'platform_game_id': 'last',
                    'games': {'name': 'Last game'},
                  },
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
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          currentUserIdProvider.overrideWithValue('owner'),
        ],
      );
      addTearDown(container.dispose);
      expect((await container.read(basicLibraryProvider.future)).length, 501);
      expect(calls, 2);
    },
  );

  testWidgets(
    'timeout opens searchable basic library and detailed retry recovers',
    (tester) async {
      var retry = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedGamesProvider.overrideWith((ref) async {
              if (!retry) {
                throw const PostgrestException(
                  message: 'statement timeout',
                  code: '57014',
                );
              }
              return [];
            }),
            basicLibraryProvider.overrideWith(
              (ref) async => [
                {
                  'platform_id': 4,
                  'platform_game_id': 'a',
                  'games': {'name': 'Test game'},
                  'achievements_earned': 2,
                  'total_achievements': 10,
                },
              ],
            ),
          ],
          child: const MaterialApp(home: UnifiedGamesListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test game'), findsOneWidget);
      expect(find.textContaining('2/10 achievements synced'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No games found.'), findsOneWidget);
      retry = true;
      await tester.tap(find.text('Retry detailed stats'));
      await tester.pumpAndSettle();
      expect(find.byType(BasicLibrary), findsNothing);
    },
  );
}
