import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart' as app;
import 'package:statusxp/data/repositories/flex_room_repository.dart';
import 'package:statusxp/domain/flex_room_data.dart';
import 'package:statusxp/ui/screens/flex_room_screen.dart';

const tile = FlexTile(
  achievementId: 0,
  achievementName: 'A memorable achievement',
  gameName: 'A favorite game',
  platform: 'psn',
  rarityPercent: 0.8,
  statusXP: 30,
);
final room = FlexRoomData(
  userId: 'owner',
  lastUpdated: DateTime.utc(2026, 9, 13),
  flexOfAllTime: tile,
  rarestFlex: tile,
  mostTimeSunk: tile,
  sweattiestPlatinum: tile,
);

class FailedSaveRepository extends FlexRoomRepository {
  FailedSaveRepository(super.client);
  int recentLoads = 0;
  @override
  Future<List<RecentFlex>> getRecentFlexes(String userId) async {
    recentLoads++;
    if (recentLoads == 1) throw StateError('offline');
    return [];
  }

  @override
  Future<bool> updateFlexRoomData(
    FlexRoomData data, {
    Map<String, dynamic>? existingConfiguration,
  }) async => false;
}

void main() {
  Future<List<String>> showRoom(
    WidgetTester tester,
    FlexRoomData data, {
    double scale = 1,
  }) async {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r.url.path);
        return http.Response(
          jsonEncode(
            r.url.path.endsWith('/profiles')
                ? {'psn_online_id': 'Player'}
                : null,
          ),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          app.currentUserIdProvider.overrideWithValue('owner'),
          app.supabaseClientProvider.overrideWithValue(client),
          flexRoomRepositoryProvider.overrideWithValue(
            FailedSaveRepository(client),
          ),
          flexRoomDataProvider('owner').overrideWith((ref) async => data),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const FlexRoomScreen(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    return requests;
  }

  testWidgets(
    'highlights load on tab selection and failures retry independently',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showRoom(tester, room);
      final element = tester.element(find.byType(FlexRoomScreen));
      final container = ProviderScope.containerOf(element);
      final repository =
          container.read(flexRoomRepositoryProvider) as FailedSaveRepository;
      expect(repository.recentLoads, 0);
      await tester.ensureVisible(find.text('Recent Flexes'));
      await tester.tap(find.text('Recent Flexes'));
      await tester.pumpAndSettle();
      expect(repository.recentLoads, 1);
      expect(
        find.text('Recent highlights could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text('No recent flexes yet.'), findsNothing);
      await tester.ensureVisible(find.text('Retry highlights'));
      await tester.tap(find.text('Retry highlights'));
      await tester.pumpAndSettle();
      expect(repository.recentLoads, 2);
      expect(find.text('No recent flexes yet.'), findsOneWidget);
      await tester.tap(find.text('Showcase'));
      await tester.pumpAndSettle();
      expect(find.text('A memorable achievement'), findsWidgets);
    },
  );

  for (final width in [390.0, 1240.0]) {
    testWidgets('showcase fits $width and loads profile once', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = await showRoom(tester, room);

      expect(requests.where((p) => p.endsWith('/profiles')).length, 1);
      expect(
        requests.where((p) => p.endsWith('/user_selected_title')).length,
        1,
      );
      final grids = tester.widgetList<GridView>(find.byType(GridView));
      final grid =
          grids.first.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(grid.crossAxisCount, width >= 1000 ? 4 : 2);
    });
  }
  testWidgets('empty room presents an actionable sync prompt', (tester) async {
    await showRoom(
      tester,
      FlexRoomData(userId: 'owner', lastUpdated: DateTime.now()),
    );
    expect(find.text('Connect or sync a platform'), findsOneWidget);
  });
  testWidgets('failed save keeps editing available and reports failure', (
    tester,
  ) async {
    await showRoom(tester, room);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to save changes'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
