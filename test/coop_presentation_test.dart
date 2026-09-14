import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/ui/widgets/coop_confirmed_session.dart';

TrophyHelpRequest request({
  String platform = 'psn',
  String status = 'open',
  DateTime? confirmed,
  DateTime? scheduled,
}) => TrophyHelpRequest(
  id: 'request',
  userId: 'owner',
  gameId: 'shared-id',
  gameTitle: 'Game',
  achievementId: 'goal',
  achievementName: 'Goal',
  platform: platform,
  status: status,
  helpersNeeded: 3,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
  lastConfirmedAt: confirmed,
  scheduledAt: scheduled,
  platformUsername: 'HostName',
);
TrophyHelpResponse response(String helper, {String status = 'accepted'}) =>
    TrophyHelpResponse(
      id: 'offer-$helper',
      requestId: 'request',
      helperUserId: helper,
      helperPsnOnlineId: 'PSN-$helper',
      status: status,
      createdAt: DateTime.utc(2026),
    );

void main() {
  test(
    'artwork uses one query and preserves platform plus game identity',
    () async {
      var queries = 0;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          queries++;
          expect(
            r.url.queryParameters['platform_game_id'],
            contains('shared-id'),
          );
          return http.Response(
            jsonEncode([
              {
                'platform_id': 1,
                'platform_game_id': 'shared-id',
                'cover_url': 'https://test.invalid/psn',
              },
              {
                'platform_id': 4,
                'platform_game_id': 'shared-id',
                'cover_url': 'https://test.invalid/steam',
              },
              {
                'platform_id': 10,
                'platform_game_id': 'shared-id',
                'cover_url': 'https://test.invalid/xbox',
              },
            ]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = TrophyHelpService(client);
      final art = await service.getCoopArtwork([
        request(),
        request(),
        request(platform: 'steam'),
      ]);
      expect(queries, 1);
      expect(art, {
        (platform: 'psn', gameId: 'shared-id'): 'https://test.invalid/psn',
        (platform: 'steam', gameId: 'shared-id'): 'https://test.invalid/steam',
      });
      expect(await service.getCoopArtwork([]), isEmpty);
      expect(queries, 1);
    },
  );
  test(
    'only genuine confirmation affects freshness; past sessions still need attention',
    () {
      final now = DateTime.utc(2026, 9, 13);
      expect(request().needsConfirmation(now), true);
      expect(
        request(
          confirmed: now.subtract(const Duration(days: 1)),
        ).needsConfirmation(now),
        false,
      );
      expect(
        request(
          confirmed: now,
          scheduled: now.subtract(const Duration(hours: 1)),
        ).needsConfirmation(now),
        true,
      );
      expect(request(status: 'completed').needsConfirmation(now), false);
      final restored = TrophyHelpRequest.fromJson(
        request(confirmed: now).toJson(),
      );
      expect(restored.lastConfirmedAt, now);
    },
  );
  Future<void> panel(
    WidgetTester tester,
    String? user,
    List<TrophyHelpResponse> responses, {
    String status = 'open',
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoopConfirmedSession(
              request: request(status: status),
              responses: responses,
              currentUserId: user,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'host panel deduplicates confirmed players and excludes pending offers',
    (tester) async {
      await panel(tester, 'owner', [
        response('helper'),
        response('helper'),
        response('pending', status: 'pending'),
      ]);
      expect(find.text('1 of 3 additional players confirmed'), findsOneWidget);
      expect(find.text('PSN-helper'), findsOneWidget);
      expect(find.text('PSN-pending'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'accepted helper sees host contact and local next step, not false team totals',
    (tester) async {
      await panel(tester, 'helper', [response('helper')]);
      expect(find.text('You’re on the team'), findsOneWidget);
      expect(find.text('HostName'), findsOneWidget);
      expect(find.textContaining('of 3 additional players'), findsNothing);
    },
  );
  testWidgets('unrelated viewer gets no confirmed-session panel', (
    tester,
  ) async {
    await panel(tester, 'outsider', [response('helper')]);
    expect(find.text('HostName'), findsNothing);
    expect(find.text('Your confirmed team'), findsNothing);
  });
  testWidgets(
    'completed sessions show the outcome instead of instructions to arrange a session',
    (tester) async {
      await panel(tester, 'helper', [
        response('helper', status: 'completed'),
      ], status: 'completed');
      expect(find.text('Goal completed'), findsOneWidget);
      expect(find.textContaining('Next:'), findsNothing);
    },
  );
}
