import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/create_trophy_request_dialog.dart';
import 'package:statusxp/ui/widgets/coop_session_summary.dart';

TrophyHelpRequest fixture({DateTime? scheduledAt, int helpers = 1}) =>
    TrophyHelpRequest(
      id: 'request',
      userId: 'owner',
      gameId: 'game',
      gameTitle: 'Our game',
      achievementId: 'goal',
      achievementName: 'Finish together',
      platform: 'psn',
      status: 'open',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      scheduledAt: scheduledAt,
      sessionUtcOffsetMinutes: scheduledAt?.timeZoneOffset.inMinutes,
      helpersNeeded: helpers,
    );

class SessionService extends TrophyHelpService {
  SessionService()
    : super(
        SupabaseClient(
          'https://test.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  DateTime? start;
  int? helpers;
  int writes = 0;
  @override
  Future<TrophyHelpRequest> createRequest({
    required String gameId,
    required String gameTitle,
    required String achievementId,
    required String achievementName,
    required String platform,
    String? description,
    String? availability,
    String? platformUsername,
    DateTime? scheduledAt,
    int helpersNeeded = 1,
  }) async {
    start = scheduledAt;
    helpers = helpersNeeded;
    writes++;
    return fixture(scheduledAt: start, helpers: helpersNeeded);
  }
}

void main() {
  test(
    'legacy requests default to flexible two-person sessions and planned fields round-trip',
    () {
      final original = fixture(
        scheduledAt: DateTime.utc(2026, 11, 1, 6, 30),
        helpers: 3,
      );
      final restored = TrophyHelpRequest.fromJson(original.toJson());
      expect(restored.scheduledAt, original.scheduledAt);
      expect(restored.helpersNeeded, 3);
      expect(
        restored.copyWith(status: 'assigned').scheduledAt,
        original.scheduledAt,
      );
      final legacy = original.toJson()
        ..remove('scheduled_at')
        ..remove('helpers_needed')
        ..remove('session_utc_offset_minutes');
      expect(TrophyHelpRequest.fromJson(legacy).helpersNeeded, 1);
      expect(TrophyHelpRequest.fromJson(legacy).scheduledAt, isNull);
      expect(coopUtcOffset(const Duration(minutes: -210)), 'UTC-03:30');
      expect(coopUtcOffset(const Duration(minutes: 345)), 'UTC+05:45');
    },
  );
  test('accept, decline and completion each call one atomic RPC', () async {
    final calls = <http.Request>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        calls.add(r);
        return http.Response('', 204, request: r);
      }),
    );
    addTearDown(client.dispose);
    final service = TrophyHelpService(client);
    await service.acceptHelper('offer');
    await service.declineHelper('other');
    await service.updateRequestStatus('request', 'completed');
    expect(calls.map((r) => r.url.path), [
      '/rest/v1/rpc/accept_coop_offer',
      '/rest/v1/rpc/decline_coop_offer',
      '/rest/v1/rpc/finish_coop_request',
    ]);
    expect(jsonDecode(calls.last.body), {
      'p_request_id': 'request',
      'p_status': 'completed',
    });
  });

  Future<void> showForm(WidgetTester tester, SessionService service) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trophyHelpServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const CreateTrophyRequestDialog(
                    gameId: 'game',
                    gameTitle: 'Our game',
                    achievementId: 'goal',
                    achievementName: 'Finish together',
                    platform: 'psn',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('creation can retain flexible timing', (tester) async {
    final service = SessionService();
    await showForm(tester, service);
    await tester.scrollUntilVisible(
      find.text('Create Request'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create Request'));
    await tester.pumpAndSettle();
    expect(service.start, isNull);
    expect(service.helpers, 1);
    expect(service.writes, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'creation selects a future start and multiple additional players',
    (tester) async {
      final service = SessionService();
      await showForm(tester, service);
      await tester.scrollUntilVisible(
        find.text('1 player besides you'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('1 player besides you'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 players besides you').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Set start time'));
      await tester.tap(find.text('Set start time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Keep flexible'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Create Request'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create Request'));
      await tester.pumpAndSettle();
      expect(service.helpers, 3);
      expect(service.start!.isAfter(DateTime.now()), isTrue);
      expect(service.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
