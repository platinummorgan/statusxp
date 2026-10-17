import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/meta_achievement_repository.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
import 'package:statusxp/services/achievement_checker_service.dart';
import 'package:statusxp/services/platform_achievement_checker.dart';
import 'package:statusxp/state/app_achievement_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/achievements_screen.dart';

SupabaseClient clientFor(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://test.invalid',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response(
      response.body,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

// Initialize the client's JSON isolate outside Flutter's fake clock.
Future<SupabaseClient> widgetClient(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final client = clientFor((_) async => jsonResponse([]));
      await client.from('warmup').select();
      return client;
    }))!;

MetaAchievement trophy({bool unlocked = false}) => MetaAchievement(
  id: 'psn_first_trophy',
  category: 'volume',
  defaultTitle: 'First Trophy',
  description: 'Unlock your first PlayStation trophy',
  sortOrder: 100,
  requiredPlatforms: ['psn'],
  unlockedAt: unlocked ? DateTime.utc(2026) : null,
);

class PendingChecker extends AchievementCheckerService {
  PendingChecker(super.client);
  final result = Completer<List<String>>();
  @override
  Future<List<String>> checkAndUnlockAchievements(String userId) =>
      result.future;
}

class TestRepository extends MetaAchievementRepository {
  TestRepository(super.client, this.load);
  final Future<List<MetaAchievement>> Function() load;
  @override
  Future<List<MetaAchievement>> getAllAchievements(
    String userId, {
    Set<String>? connectedPlatforms,
  }) => load();
}

class RecoveringChecker extends AchievementCheckerService {
  RecoveringChecker(super.client);
  int checks = 0;
  @override
  Future<List<String>> checkAndUnlockAchievements(String userId) async {
    if (++checks == 1) throw StateError('Offline');
    return [];
  }
}

Future<void> renderAchievements(
  WidgetTester tester,
  SupabaseClient client,
  AchievementCheckerService checker,
  TestRepository repository, {
  Stream<String> updates = const Stream.empty(),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        supabaseClientProvider.overrideWithValue(client),
        connectedPlatformsProvider.overrideWith((ref) async => {'psn'}),
        achievementCheckerServiceProvider.overrideWithValue(checker),
        metaAchievementRepositoryProvider.overrideWithValue(repository),
        appAchievementUpdatesProvider.overrideWith((ref) => updates),
      ],
      child: const MaterialApp(home: AchievementsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('screen and sync checkers call the same complete-history RPC', () async {
    var requests = 0;
    final client = clientFor((request) async {
      requests++;
      expect(request.url.path, '/rest/v1/rpc/reconcile_app_achievements');
      expect(jsonDecode(request.body), {'p_user_id': 'owner'});
      return jsonResponse([
        {'achievement_id': 'psn_10000_trophies'},
      ]);
    });
    addTearDown(client.dispose);
    expect(
      await AchievementCheckerService(
        client,
      ).checkAndUnlockAchievements('owner'),
      ['psn_10000_trophies'],
    );
    expect(
      await PlatformAchievementChecker(
        client,
      ).checkAndUnlockAchievements('owner'),
      ['psn_10000_trophies'],
    );
    expect(requests, 2);
  });

  test(
    'checker surfaces server failure and malformed results instead of reporting no awards',
    () async {
      final offline = clientFor(
        (_) async =>
            jsonResponse({'message': 'Unavailable', 'code': '57014'}, 500),
      );
      final malformed = clientFor((_) async => jsonResponse(true));
      addTearDown(offline.dispose);
      addTearDown(malformed.dispose);
      await expectLater(
        AchievementCheckerService(offline).checkAndUnlockAchievements('owner'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        AchievementCheckerService(
          malformed,
        ).checkAndUnlockAchievements('owner'),
        throwsFormatException,
      );
    },
  );

  test(
    'earned awards survive disconnecting a platform and global goals stay visible',
    () async {
      Map<String, Object?> definition(String id, List<String> platforms) => {
        'id': id,
        'category': 'volume',
        'default_title': id,
        'description': 'A goal',
        'sort_order': 1,
        'required_platforms': platforms,
      };
      final client = clientFor((request) async {
        if (request.url.path.endsWith('/meta_achievements')) {
          return jsonResponse([
            definition('psn_first_trophy', ['psn']),
            definition('xbox_first_unlock', ['xbox']),
            definition('steam_first_unlock', ['steam']),
            definition('cross_statusxp_500', []),
          ]);
        }
        return jsonResponse([
          {
            'achievement_id': 'steam_first_unlock',
            'unlocked_at': '2026-01-01T00:00:00Z',
            'custom_title': 'My title',
          },
        ]);
      });
      addTearDown(client.dispose);
      final rows = await MetaAchievementRepository(
        client,
      ).getAllAchievements('owner', connectedPlatforms: {'psn'});
      expect(rows.map((a) => a.id), [
        'psn_first_trophy',
        'steam_first_unlock',
        'cross_statusxp_500',
      ]);
      expect(
        rows.firstWhere((a) => a.id == 'steam_first_unlock').displayTitle,
        'My title',
      );
    },
  );

  test(
    'list loading errors are not disguised as an empty achievement catalog',
    () async {
      final client = clientFor(
        (_) async => jsonResponse({'message': 'Offline'}, 503),
      );
      addTearDown(client.dispose);
      await expectLater(
        MetaAchievementRepository(client).getAllAchievements('owner'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  testWidgets('unlock dialog waits for refreshed names before it appears', (
    tester,
  ) async {
    final client = await widgetClient(tester);
    addTearDown(() => tester.runAsync(client.dispose));
    final checker = PendingChecker(client);
    final refreshed = Completer<List<MetaAchievement>>();
    var reads = 0;
    final repository = TestRepository(
      client,
      () => ++reads == 1 ? Future.value([trophy()]) : refreshed.future,
    );
    await renderAchievements(tester, client, checker, repository);
    checker.result.complete(['psn_first_trophy']);
    await tester.pump();
    await tester.pump();
    expect(find.text('🎉 Achievements Unlocked!'), findsNothing);
    refreshed.complete([trophy(unlocked: true)]);
    await tester.pumpAndSettle();
    expect(find.text('🎉 Achievements Unlocked!'), findsOneWidget);
    expect(find.text('• First Trophy'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'server-side background awards update the screen without a manual refresh',
    (tester) async {
      final client = await widgetClient(tester);
      addTearDown(() => tester.runAsync(client.dispose));
      final checker = PendingChecker(client)..result.complete([]);
      final updates = StreamController<String>();
      addTearDown(updates.close);
      var unlocked = false;
      final repository = TestRepository(
        client,
        () async => [trophy(unlocked: unlocked)],
      );
      await renderAchievements(
        tester,
        client,
        checker,
        repository,
        updates: updates.stream,
      );
      updates.add('initial');
      await tester.pumpAndSettle();
      expect(find.text('0 / 1'), findsOneWidget);
      unlocked = true;
      updates.add('server award');
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty catalogs render safely', (tester) async {
    final client = await widgetClient(tester);
    addTearDown(() => tester.runAsync(client.dispose));
    final checker = PendingChecker(client)..result.complete([]);
    final repository = TestRepository(client, () async => []);
    await renderAchievements(tester, client, checker, repository);
    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed checks recover automatically without a refresh button', (
    tester,
  ) async {
    final client = await widgetClient(tester);
    addTearDown(() => tester.runAsync(client.dispose));
    final checker = RecoveringChecker(client);
    final repository = TestRepository(client, () async => [trophy()]);
    await renderAchievements(tester, client, checker, repository);
    expect(checker.checks, 1);
    expect(
      find.textContaining('Achievement updates will retry'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(checker.checks, 2);
    expect(find.textContaining('Achievement updates will retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
