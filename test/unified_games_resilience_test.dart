import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/unified_games_repository.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/dashboard_games_list.dart';

Map<String, Object?> gameRow(String name) => {
  'name': name,
  'cover_url': 'https://test.invalid/cover.png',
  'platforms': [
    {
      'code': 'psn',
      'platform_id': 1,
      'platform_game_id': name,
      'game_title_id': name,
      'earned_trophies': 2,
      'total_trophies': 10,
      'completion': 20,
      'statusxp': 100,
      'platinum_trophies': 1,
      'last_trophy_earned_at': '2026-10-17T12:00:00Z',
    },
  ],
};

const oldGame = UnifiedGame(
  title: 'Saved game',
  platforms: [],
  overallCompletion: 0,
);
const freshGame = UnifiedGame(
  title: 'Fresh game',
  platforms: [],
  overallCompletion: 0,
);

SupabaseClient mockClient(
  Future<List<Map<String, Object?>>> Function(http.Request) respond,
) => SupabaseClient(
  'https://test.invalid',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient(
    (request) async => http.Response(
      jsonEncode(await respond(request)),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    ),
  ),
);

class RecoveringLibrary extends UnifiedGamesRepository {
  RecoveringLibrary(this.load, {this.saved}) : super(Supabase.instance.client);
  final Future<List<UnifiedGame>> Function(String user, int call) load;
  final List<UnifiedGame>? saved;
  int calls = 0;
  @override
  Future<List<UnifiedGame>> getUnifiedGames(String userId) =>
      load(userId, ++calls);
  @override
  Future<List<UnifiedGame>> getDashboardGames(String userId) =>
      load(userId, ++calls);
  @override
  Future<List<UnifiedGame>?> readSavedGames(String userId) async =>
      userId == 'owner' ? saved : null;
  @override
  Future<List<UnifiedGame>?> readSavedDashboardGames(String userId) =>
      readSavedGames(userId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.invalid',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'dashboard, full library and public requests keep separate private caches',
    () async {
      final client = mockClient(
        (request) async => request.url.path.endsWith('/get_dashboard_games')
            ? [gameRow('Recent')]
            : [gameRow('First'), gameRow('Second')],
      );
      addTearDown(client.dispose);
      final repository = UnifiedGamesRepository(client);
      final full = await repository.getUnifiedGames('owner');
      final recent = await repository.getDashboardGames('owner');
      final reopened = UnifiedGamesRepository(client);
      expect(await reopened.readSavedGames('owner'), full);
      expect(await reopened.readSavedDashboardGames('owner'), recent);
      expect(await reopened.readSavedGames('another-user'), isNull);
      await repository.getPublicUnifiedGames('public-user');
      expect(await reopened.readSavedGames('public-user'), isNull);
      expect(recent.single.platforms.single.platformGameId, 'Recent');
      expect(
        recent.single.platforms.single.lastTrophyEarnedAt,
        DateTime.utc(2026, 10, 17, 12),
      );
    },
  );

  test(
    'an old request finishing late cannot overwrite newer library data',
    () async {
      final first = Completer<List<Map<String, Object?>>>();
      final second = Completer<List<Map<String, Object?>>>();
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      var calls = 0;
      final client = mockClient((_) {
        if (++calls == 1) {
          firstStarted.complete();
          return first.future;
        }
        secondStarted.complete();
        return second.future;
      });
      addTearDown(client.dispose);
      final repository = UnifiedGamesRepository(client);
      final old = repository.getUnifiedGames('owner');
      await firstStarted.future;
      final newer = repository.getUnifiedGames('owner');
      await secondStarted.future;
      second.complete([gameRow('New')]);
      await newer;
      first.complete([gameRow('Old')]);
      await old;
      expect((await repository.readSavedGames('owner'))!.single.title, 'New');
    },
  );

  test(
    'damaged library caches are ignored instead of crashing a load',
    () async {
      SharedPreferences.setMockInitialValues({
        'unified_games_v1_owner': '{invalid',
        'dashboard_games_v1_owner': '[{"name":4}]',
      });
      final repository = UnifiedGamesRepository(Supabase.instance.client);
      expect(await repository.readSavedGames('owner'), isNull);
      expect(await repository.readSavedDashboardGames('owner'), isNull);
    },
  );

  for (final dashboard in [false, true]) {
    final name = dashboard ? 'dashboard' : 'full library';
    final provider = dashboard ? dashboardGamesProvider : unifiedGamesProvider;
    final display = dashboard
        ? dashboardGamesDisplayProvider
        : unifiedGamesDisplayProvider;
    final saved = dashboard
        ? savedDashboardGamesProvider
        : savedUnifiedGamesProvider;
    testWidgets(
      '$name keeps cached games and automatically retries a failed refresh',
      (tester) async {
        final pending = Completer<List<UnifiedGame>>();
        final repository = RecoveringLibrary(
          (_, call) => call == 1 ? pending.future : Future.value([freshGame]),
          saved: [oldGame],
        );
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            unifiedGamesRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(display, (_, _) {});
        addTearDown(subscription.close);
        await container.read(saved.future);
        expect(container.read(display).valueOrNull, [oldGame]);
        expect(container.read(provider).isLoading, isTrue);
        pending.completeError(
          const PostgrestException(message: 'statement timeout', code: '57014'),
        );
        expect(await container.read(provider.future), [oldGame]);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(repository.calls, 2);
        expect(container.read(display).valueOrNull, [freshGame]);
      },
    );

    testWidgets('$name also retries when there is no saved library', (
      tester,
    ) async {
      final repository = RecoveringLibrary((_, call) async {
        if (call == 1) throw StateError('Network unavailable');
        return [freshGame];
      });
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          unifiedGamesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(display, (_, _) {});
      addTearDown(subscription.close);
      await expectLater(container.read(provider.future), throwsStateError);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(container.read(display).valueOrNull, [freshGame]);
    });

    testWidgets(
      '$name hides the previous account immediately when switching users',
      (tester) async {
        final owner = StateProvider<String?>((ref) => 'owner');
        final next = Completer<List<UnifiedGame>>();
        final repository = RecoveringLibrary(
          (user, _) => user == 'owner' ? Future.value([oldGame]) : next.future,
          saved: [oldGame],
        );
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
            unifiedGamesRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(display, (_, _) {});
        addTearDown(subscription.close);
        await container.read(provider.future);
        expect(container.read(display).valueOrNull, [oldGame]);
        container.read(owner.notifier).state = 'another-user';
        expect(container.read(display).valueOrNull, isNull);
        await container.read(saved.future);
        expect(container.read(display).valueOrNull, isNull);
        container.read(owner.notifier).state = null;
        await container.read(provider.future);
        expect(container.read(display).valueOrNull, isEmpty);
        next.complete([freshGame]);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'dashboard provides view-all navigation for a bounded 20-game response',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardGamesList(
                games: AsyncData(List.filled(20, oldGame)),
                gameBuilder: (_) => const SizedBox(height: 5),
                onViewAll: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View All Games →'));
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'temporary dashboard errors explain automatic recovery without database details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardGamesList(
              games: AsyncError(
                StateError('sensitive database query'),
                StackTrace.empty,
              ),
              gameBuilder: (_) => const SizedBox(),
              onViewAll: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Reconnecting automatically'), findsOneWidget);
      expect(find.textContaining('sensitive database query'), findsNothing);
    },
  );
}
