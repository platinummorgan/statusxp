import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/coop_partners_screen.dart';

CoopEntry entry(String id, {String owner = 'other', String? offer}) =>
    CoopEntry(
      TrophyHelpRequest(
        id: id,
        userId: owner,
        profileId: owner,
        gameId: 'game',
        gameTitle: 'Game $id',
        achievementId: 'achievement',
        achievementName: 'Finish the final mission together',
        platform: 'psn',
        availability:
            'Weekends after 8 pm Eastern; flexible if we plan ahead together',
        status: offer == 'accepted' ? 'assigned' : 'open',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      offerStatus: offer,
    );

class FakeCoop extends TrophyHelpService {
  FakeCoop()
    : super(
        SupabaseClient(
          'https://test.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final calls =
      <({CoopFeed feed, String? platform, String search, int offset})>[];
  Future<List<CoopEntry>> Function(CoopFeed, int, String)? respond;
  Future<Map<CoopGameKey, String>> Function()? artwork;
  bool reconfirmed = false;
  @override
  Future<Map<CoopGameKey, String>> getCoopArtwork(
    List<TrophyHelpRequest> requests,
  ) async => artwork?.call() ?? {};
  @override
  Future<void> reconfirmRequest(
    String requestId, {
    bool clearPastSchedule = false,
  }) async {
    reconfirmed = true;
  }

  @override
  Future<List<CoopEntry>> getCoopPage({
    required CoopFeed feed,
    String? platform,
    String search = '',
    int offset = 0,
    int limit = 24,
  }) async {
    calls.add((feed: feed, platform: platform, search: search, offset: offset));
    return respond?.call(feed, offset, search) ?? [entry('one')];
  }
}

void main() {
  Future<void> showHub(
    WidgetTester tester,
    FakeCoop service, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          trophyHelpServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const CoopPartnersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 1240.0]) {
    testWidgets('hub fits $width with long availability and larger text', (
      tester,
    ) async {
      await showHub(tester, FakeCoop(), width: width, scale: 1.3);
      expect(find.text('Request help'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Offer help'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Offer help'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('slow or failed artwork never blocks the request actions', (
    tester,
  ) async {
    final art = Completer<Map<CoopGameKey, String>>();
    final service = FakeCoop()..artwork = () => art.future;
    await showHub(tester, service);
    await tester.scrollUntilVisible(
      find.text('Offer help'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Offer help'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    art.completeError(StateError('artwork unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Offer help'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('owner confirmation refreshes the freshness label', (
    tester,
  ) async {
    final service = FakeCoop();
    service.respond = (_, _, _) async => [
      CoopEntry(
        entry('mine', owner: 'owner').request.copyWith(
          lastConfirmedAt: service.reconfirmed ? DateTime.now() : null,
        ),
      ),
    ];
    await showHub(tester, service);
    expect(find.text('Needs confirmation'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Still looking'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Still looking'));
    await tester.pumpAndSettle();
    expect(service.reconfirmed, false);
    await tester.tap(find.text('Confirm request'));
    await tester.pumpAndSettle();
    expect(service.reconfirmed, true);
    expect(find.text('Needs confirmation'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('Owner confirmed'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Owner confirmed'), findsOneWidget);
  });
  testWidgets('search is debounced and platform filtering reaches service', (
    tester,
  ) async {
    final service = FakeCoop();
    await showHub(tester, service);
    await tester.enterText(find.byType(TextField), 'Halo');
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.calls.length, 1);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(service.calls.last.search, 'Halo');
    await tester.tap(find.text('Xbox'));
    await tester.pumpAndSettle();
    expect(service.calls.last.platform, 'xbox');
  });
  testWidgets('My offers shows accepted status and partner action', (
    tester,
  ) async {
    final service = FakeCoop()
      ..respond = (feed, offset, search) async => [
        entry('accepted', offer: 'accepted'),
      ];
    await showHub(tester, service);
    await tester.tap(find.text('My offers'));
    await tester.pumpAndSettle();
    expect(service.calls.last.feed, CoopFeed.offers);
    await tester.scrollUntilVisible(
      find.text('View partner details'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Your offer accepted'), findsOneWidget);
    expect(find.text('Offer help'), findsNothing);
  });
  testWidgets('errors offer retry instead of an empty community', (
    tester,
  ) async {
    var fail = true;
    final service = FakeCoop()
      ..respond = (_, _, _) async {
        if (fail) throw StateError('offline');
        return [];
      };
    await showHub(tester, service);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Start the next team-up.'), findsNothing);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Start the next team-up.'), findsOneWidget);
  });
  testWidgets('older search results cannot replace newer filters', (
    tester,
  ) async {
    final old = Completer<List<CoopEntry>>();
    final service = FakeCoop()
      ..respond = (_, _, search) => search == 'old'
          ? old.future
          : Future.value([entry(search.isEmpty ? 'initial' : search)]);
    await showHub(tester, service);
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    old.complete([entry('old')]);
    await tester.pumpAndSettle();
    expect(find.text('Game new'), findsOneWidget);
    expect(find.text('Game old'), findsNothing);
  });
  testWidgets('own request has management instead of offering help', (
    tester,
  ) async {
    final service = FakeCoop()
      ..respond = (_, _, _) async => [entry('mine', owner: 'owner')];
    await showHub(tester, service);
    await tester.scrollUntilVisible(
      find.text('Manage request'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Manage request'), findsOneWidget);
    expect(find.text('Offer help'), findsNothing);
  });
  testWidgets('request help explains the existing achievement selection flow', (
    tester,
  ) async {
    await showHub(tester, FakeCoop());
    await tester.tap(find.text('Request help'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed next page retries the same offset and retains existing requests',
    (tester) async {
      var fail = true;
      final service = FakeCoop()
        ..respond = (_, offset, _) async {
          if (offset == 0) return [for (var i = 0; i < 24; i++) entry('$i')];
          if (fail) throw StateError('offline');
          return [entry('last')];
        };
      await showHub(tester, service, width: 1240);
      await tester.scrollUntilVisible(
        find.text('Load more'),
        700,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(service.calls.last.offset, 24);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Game 23'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(service.calls.last.offset, 24);
      await tester.scrollUntilVisible(
        find.text('Game last'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Game last'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
  );
}
