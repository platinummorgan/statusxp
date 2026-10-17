import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/data/dashboard_cache.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/new_dashboard_screen.dart';
import 'helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saved stats survive a new cache instance and stay account scoped',
    () async {
      await DashboardCache().write('first', sampleDashboardStats);
      expect(await DashboardCache().read('first'), sampleDashboardStats);
      expect(await DashboardCache().read('second'), isNull);
    },
  );

  test('damaged saved stats are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_stats_v1_first': '{bad',
    });
    expect(await DashboardCache().read('first'), isNull);
  });

  test(
    'saved stats display before the network and update automatically',
    () async {
      await DashboardCache().write('first', sampleDashboardStats);
      final network = Completer<DashboardStats?>();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('first'),
          dashboardStatsProvider.overrideWith((ref) => network.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        dashboardDisplayStatsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(savedDashboardStatsProvider.future);
      expect(
        container.read(dashboardDisplayStatsProvider).valueOrNull,
        sampleDashboardStats,
      );
      expect(container.read(dashboardStatsProvider).isLoading, isTrue);

      final updated = sampleDashboardStats.copyWith(totalStatusXP: 9876);
      network.complete(updated);
      await container.read(dashboardStatsProvider.future);
      expect(
        container.read(dashboardDisplayStatsProvider).valueOrNull,
        updated,
      );

      // A resume/sync refresh keeps existing stats visible while it loads.
      container.invalidate(dashboardStatsProvider);
      expect(
        container.read(dashboardDisplayStatsProvider).valueOrNull,
        updated,
      );
      await container.read(dashboardStatsProvider.future);
    },
  );

  test('offline loading retains saved stats', () async {
    await DashboardCache().write('first', sampleDashboardStats);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('first'),
        dashboardStatsProvider.overrideWith(
          (ref) async => throw StateError('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dashboardDisplayStatsProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await expectLater(
      container.read(dashboardStatsProvider.future),
      throwsStateError,
    );
    await container.read(savedDashboardStatsProvider.future);
    expect(
      container.read(dashboardDisplayStatsProvider).valueOrNull,
      sampleDashboardStats,
    );
  });

  test(
    'account changes and signout never display previous account stats',
    () async {
      final owner = StateProvider<String?>((ref) => 'first');
      await DashboardCache().write('first', sampleDashboardStats);
      final pending = Completer<DashboardStats?>();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
          dashboardStatsProvider.overrideWith((ref) {
            final id = ref.watch(currentUserIdProvider);
            return id == 'first'
                ? Future.value(sampleDashboardStats)
                : pending.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        dashboardDisplayStatsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(dashboardStatsProvider.future);
      await container.read(savedDashboardStatsProvider.future);
      expect(
        container.read(dashboardDisplayStatsProvider).valueOrNull,
        sampleDashboardStats,
      );

      container.read(owner.notifier).state = 'second';
      expect(container.read(dashboardDisplayStatsProvider).valueOrNull, isNull);
      await container.read(savedDashboardStatsProvider.future);
      expect(container.read(dashboardDisplayStatsProvider).valueOrNull, isNull);

      container.read(owner.notifier).state = null;
      expect(container.read(dashboardDisplayStatsProvider).valueOrNull, isNull);
      pending.complete(null);
    },
  );

  testWidgets('first launch shows the app shell and makes one stats request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final network = Completer<DashboardStats?>();
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...getTestProviderOverrides(),
          dashboardStatsProvider.overrideWith((ref) {
            reads++;
            return network.future;
          }),
          savedDashboardStatsProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: TickerMode(enabled: false, child: NewDashboardScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your dashboard'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(reads, 1);

    network.complete(sampleDashboardStats);
    await tester.pumpAndSettle();
    expect(find.text('MY GAMES'), findsOneWidget);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });
}
