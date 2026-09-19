import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/flex_room_repository.dart';
import 'package:statusxp/domain/flex_room_data.dart';
import 'package:statusxp/ui/widgets/achievement_picker_modal.dart';

class PickerRepository extends FlexRoomRepository {
  PickerRepository()
    : super(
        SupabaseClient(
          'https://test.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final queries = <String?>[];
  final pages = <int?>[];
  bool paginated = false;
  String? achievementQuery;
  bool fail = false;
  Completer<List<Map<String, dynamic>>>? delayed;
  @override
  Future<List<Map<String, dynamic>>> getGamesForPlatform(
    String userId,
    String platform, {
    String? searchQuery,
    int? page,
  }) async {
    queries.add(searchQuery);
    pages.add(page);
    if (fail) throw StateError('offline');
    if (delayed != null) return delayed!.future;
    if (paginated && page == 1) return [];
    return [
      {
        'game_name': 'Example game',
        'game_id': 'game',
        'platform_id': 4,
        'platform_game_id': 'game',
        'achievement_count': 1,
        'page_has_more': paginated,
      },
    ];
  }

  @override
  Future<List<FlexTile>> getAchievementsForGame(
    String userId,
    String? gameId,
    String platform, {
    String? searchQuery,
    int? page,
    int? platformId,
    String? platformGameId,
  }) async {
    achievementQuery = searchQuery;
    return [];
  }
}

void main() {
  Future<void> open(WidgetTester tester, PickerRepository repository) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flexRoomRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(
            body: AchievementPickerModal(
              userId: 'owner',
              categoryId: 'rarest',
              categoryLabel: 'Rarest',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Steam'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'paging can retry, return from an empty last page, and reset search',
    (tester) async {
      final repo = PickerRepository()..paginated = true;
      await open(tester, repo);
      repo.fail = true;
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Error loading games'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.pages, [0, 1, 1]);
      expect(find.text('No more games'), findsOneWidget);
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Example game'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'search');
      await tester.pumpAndSettle();
      expect(repo.pages.last, 0);
      expect(find.text('Page 1'), findsOneWidget);
    },
  );

  testWidgets(
    'typing is debounced and game search does not leak into achievements',
    (tester) async {
      final repo = PickerRepository();
      await open(tester, repo);
      expect(repo.queries, [null]);
      await tester.enterText(find.byType(TextField), 'Ex');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Example');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repo.queries, [null]);
      await tester.pumpAndSettle();
      expect(repo.queries, [null, 'Example']);
      await tester.tap(find.text('Example game'));
      await tester.pumpAndSettle();
      expect(repo.achievementQuery, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('failed reads show retry instead of an empty library', (
    tester,
  ) async {
    final repo = PickerRepository()..fail = true;
    await open(tester, repo);
    expect(find.text('Error loading games'), findsOneWidget);
    expect(find.text('No games yet'), findsNothing);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.queries.length, 2);
    expect(find.text('Example game'), findsOneWidget);
  });

  testWidgets('old results cannot appear while a new search is pending', (
    tester,
  ) async {
    final repo = PickerRepository();
    await open(tester, repo);
    final old = Completer<List<Map<String, dynamic>>>();
    repo.delayed = old;
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    repo.delayed = null;
    await tester.enterText(find.byType(TextField), 'new');
    old.complete([
      {'game_name': 'Stale game', 'game_id': 'old'},
    ]);
    await tester.pump();
    expect(find.text('Stale game'), findsNothing);
    await tester.pumpAndSettle();
    expect(repo.queries, [null, 'old', 'new']);
    expect(find.text('Example game'), findsOneWidget);
    expect(find.text('Stale game'), findsNothing);
  });
}
