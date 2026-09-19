import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/auth/auth_service.dart';
import 'package:statusxp/data/repositories/game_overview_repository.dart';
import 'package:statusxp/domain/game_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
import 'package:statusxp/state/statusxp_providers.dart';

User user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-09-11T00:00:00Z',
);
AuthState event(
  String? id, [
  AuthChangeEvent type = AuthChangeEvent.signedIn,
]) => AuthState(
  type,
  id == null
      ? null
      : Session(accessToken: 'test-token', tokenType: 'bearer', user: user(id)),
);

class TestAuth implements AuthService {
  final events = StreamController<AuthState>.broadcast(sync: true);
  @override
  User? currentUser;
  @override
  Stream<AuthState> get authStateChanges => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestOverview implements GameOverviewRepository {
  final requests = <(String?, Completer<GameOverview?>)>[];
  @override
  Future<GameOverview?> getGame(GameRef gameRef, {String? userId}) {
    final result = Completer<GameOverview?>();
    requests.add((userId, result));
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestAuth auth;
  late TestOverview overview;
  late ProviderContainer container;
  const game = GameRef(platformId: 1, platformGameId: 'game');
  setUp(() {
    auth = TestAuth();
    overview = TestOverview();
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        gameOverviewRepositoryProvider.overrideWithValue(overview),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await auth.events.close();
  });
  Future<void> emit(
    String? id, [
    AuthChangeEvent type = AuthChangeEvent.signedIn,
  ]) async {
    auth.events.add(event(id, type));
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }

  test(
    'restored identity follows authoritative sign-out and account changes',
    () async {
      auth.currentUser = user('A');
      final subscription = container.listen(currentUserIdProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(container.read(currentUserIdProvider), 'A');
      // Leave the snapshot stale deliberately: explicit signedOut must win.
      await emit(null, AuthChangeEvent.signedOut);
      expect(container.read(currentUserIdProvider), isNull);
      await emit('B');
      expect(container.read(currentUserIdProvider), 'B');
    },
  );

  test(
    'guest game reloads for A and B; token refresh does not reload it',
    () async {
      final provider = gameOverviewProvider(game);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      expect(overview.requests.single.$1, isNull);
      overview.requests.last.$2.complete(
        const GameOverview(ref: game, name: 'guest'),
      );
      await container.read(provider.future);
      await emit('A');
      expect(overview.requests.last.$1, 'A');
      expect(container.read(provider).isLoading, isTrue);
      expect(container.read(provider).asData, isNull);
      overview.requests.last.$2.complete(
        const GameOverview(ref: game, name: 'A', isOwned: true),
      );
      expect((await container.read(provider.future))!.name, 'A');
      final count = overview.requests.length;
      await emit('A', AuthChangeEvent.tokenRefreshed);
      expect(overview.requests, hasLength(count));
      await emit(null, AuthChangeEvent.signedOut);
      final oldGuestRequest = overview.requests.last.$2;
      await emit('B');
      overview.requests.last.$2.complete(
        const GameOverview(ref: game, name: 'B'),
      );
      oldGuestRequest.complete(const GameOverview(ref: game, name: 'obsolete'));
      expect((await container.read(provider.future))!.name, 'B');
    },
  );

  test(
    'slow account A cannot replace B; revisiting a cached route reloads',
    () async {
      final identity = container.listen(currentUserIdProvider, (_, _) {});
      addTearDown(identity.close);
      await emit('A');
      final provider = gameOverviewProvider(game);
      final subscription = container.listen(provider, (_, _) {});
      final old = overview.requests.last.$2;
      await emit('B');
      overview.requests.last.$2.complete(
        const GameOverview(ref: game, name: 'B'),
      );
      old.complete(const GameOverview(ref: game, name: 'A'));
      expect((await container.read(provider.future))!.name, 'B');
      subscription.close();
      await container.pump();
      await emit(null, AuthChangeEvent.signedOut);
      final next = container.read(provider.future);
      expect(overview.requests.last.$1, isNull);
      overview.requests.last.$2.complete(
        const GameOverview(ref: game, name: 'guest again'),
      );
      expect((await next)!.name, 'guest again');
    },
  );

  test(
    'platforms and ranks refetch for each account and clear for guests',
    () async {
      container.dispose();
      final profileQueries = <String?>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/profiles')) {
            final id = request.url.queryParameters['id'];
            profileQueries.add(id);
            return http.Response(
              jsonEncode(
                id == 'eq.A' ? {'psn_online_id': 'A'} : {'xbox_gamertag': 'B'},
              ),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode([
              {'user_id': 'A'},
              {'user_id': 'B'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          supabaseClientProvider.overrideWithValue(client),
        ],
      );
      final platforms = container.listen(connectedPlatformsProvider, (_, _) {});
      final ranks = container.listen(leaderboardRanksProvider, (_, _) {});
      addTearDown(platforms.close);
      addTearDown(ranks.close);
      expect(await container.read(connectedPlatformsProvider.future), isEmpty);
      await emit('A');
      expect(
        await container.read(connectedPlatformsProvider.future),
        {'psn'},
        reason: profileQueries.toString(),
      );
      expect(
        (await container.read(leaderboardRanksProvider.future))['global'],
        1,
      );
      await emit('B');
      expect(await container.read(connectedPlatformsProvider.future), {'xbox'});
      expect(
        (await container.read(leaderboardRanksProvider.future))['global'],
        2,
      );
      await emit(null, AuthChangeEvent.signedOut);
      expect(await container.read(connectedPlatformsProvider.future), isEmpty);
      expect(
        (await container.read(leaderboardRanksProvider.future)).values,
        everyElement(isNull),
      );
      expect(profileQueries, ['eq.A', 'eq.B']);
    },
  );
}
