import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/main.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/state/sync_completion_provider.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import '../helpers/test_helpers.dart';

void main() {
  testWidgets(
    'dashboard reloads when background sync finishes outside a sync screen',
    (tester) async {
      final events = StreamController<SyncCompletionSnapshot?>();
      addTearDown(events.close);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var reads = 0;
      var gameReads = 0;
      var total = 1234.0;
      final overrides = getTestProviderOverrides();
      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            syncCompletionProvider.overrideWith((ref) => events.stream),
            dashboardGamesProvider.overrideWith((ref) async {
              gameReads++;
              return sampleUnifiedGames;
            }),
            dashboardStatsProvider.overrideWith((ref) async {
              reads++;
              return sampleDashboardStats.copyWith(totalStatusXP: total);
            }),
          ],
          child: const TickerMode(enabled: false, child: StatusXPApp()),
        ),
      );
      await tester.pumpAndSettle();
      events.add(
        SyncCompletionSnapshot({
          'user_id': 'test-user-id',
          'psn_sync_status': 'syncing',
        }),
      );
      await tester.pumpAndSettle();
      final before = reads;
      final gamesBefore = gameReads;
      total = 4321;
      events.add(
        SyncCompletionSnapshot({
          'user_id': 'test-user-id',
          'psn_sync_status': 'success',
          'last_psn_sync_at': '2026-10-13T12:00:00Z',
        }),
      );
      await tester.pumpAndSettle();
      expect(reads, greaterThan(before));
      expect(gameReads, greaterThan(gamesBefore));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StatusXPApp)),
      );
      expect(
        container.read(dashboardStatsProvider).asData?.value?.totalStatusXP,
        4321,
      );
      expect(find.text('MY GAMES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
