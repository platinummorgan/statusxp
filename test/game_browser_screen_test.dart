import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/data/repositories/supabase_game_repository.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/game_browser_screen.dart';

class Request {
  Request(this.query, this.platform, this.sort, this.offset);
  final String? query, platform, sort;
  final int offset;
  final result = Completer<List<Map<String, dynamic>>>();
}

class CatalogRepository implements SupabaseGameRepository {
  final requests = <Request>[];
  @override
  Future<List<Map<String, dynamic>>> getAllGames({
    String? searchQuery,
    String? platformFilter,
    int limit = 100,
    int offset = 0,
    String? sortBy = 'name_asc',
  }) {
    final request = Request(searchQuery, platformFilter, sortBy, offset);
    requests.add(request);
    return request.result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Map<String, dynamic>> games(String name, [int count = 1]) =>
    List.generate(count, (i) => {'name': '$name $i'});

void main() {
  late CatalogRepository repository;
  Future<void> open(WidgetTester tester) async {
    repository = CatalogRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: GameBrowserScreen()),
      ),
    );
  }

  testWidgets('typing invalidates in-flight results before debounce finishes', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'halo');
    repository.requests[0].result.complete(games('stale'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('stale 0'), findsNothing);
    await tester.enterText(find.byType(TextField), 'halo infinite');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.requests, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.requests.last.query, 'halo infinite');
    repository.requests.last.result.complete(games('latest'));
    await tester.pump();
    expect(find.text('latest 0'), findsOneWidget);
  });

  testWidgets(
    'filter and sort replace active search and discard stale errors',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'doom');
      await tester.tap(find.text('STEAM'));
      await tester.pump();
      expect(repository.requests.last.query, 'doom');
      expect(repository.requests.last.platform, 'steam');
      final old = repository.requests.last;
      await tester.tap(find.byTooltip('Sort'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Z → A'));
      await tester.pump();
      expect(repository.requests.last.sort, 'name_desc');
      expect(repository.requests.last.offset, 0);
      repository.requests.last.result.complete(games('sorted'));
      old.result.completeError(StateError('obsolete failure'));
      repository.requests.first.result.complete(games('obsolete'));
      await tester.pumpAndSettle();
      expect(find.text('sorted 0'), findsOneWidget);
      expect(find.textContaining('Could not load'), findsNothing);
      expect(repository.requests, hasLength(3));
    },
  );

  testWidgets('old pagination cannot append after a filter change', (
    tester,
  ) async {
    await open(tester);
    repository.requests[0].result.complete(games('original', 50));
    await tester.pump();
    final list = tester.widget<ListView>(find.byType(ListView).last);
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pump();
    final page = repository.requests.last;
    expect(page.offset, 50);
    await tester.tap(find.text('XBOX'));
    await tester.pump();
    expect(repository.requests.last.offset, 0);
    repository.requests.last.result.complete(games('xbox'));
    page.result.complete(games('wrong page'));
    await tester.pump();
    expect(find.text('xbox 0'), findsOneWidget);
    expect(find.text('wrong page 0'), findsNothing);
  });

  testWidgets(
    'failed page retries the same offset and retains existing games',
    (tester) async {
      await open(tester);
      repository.requests[0].result.complete(games('kept', 50));
      await tester.pump();
      final list = tester.widget<ListView>(find.byType(ListView).last);
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pump();
      repository.requests.last.result.completeError(StateError('offline'));
      await tester.pump();
      await tester.tap(find.text('Retry loading games'));
      expect(repository.requests.last.offset, 50);
      repository.requests.last.result.complete(games('next'));
      await tester.pump();
      expect(find.text('next 0'), findsOneWidget);
      expect(find.text('Retry loading games'), findsNothing);
    },
  );

  testWidgets(
    'initial failure is retryable and disposal ignores pending work',
    (tester) async {
      await open(tester);
      repository.requests.first.result.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('No games found'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(repository.requests.last.offset, 0);
      final pending = repository.requests.last;
      await tester.enterText(find.byType(TextField), 'pending');
      await tester.pumpWidget(const SizedBox.shrink());
      pending.result.complete(games('disposed'));
      await tester.pump(const Duration(seconds: 1));
      expect(repository.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
