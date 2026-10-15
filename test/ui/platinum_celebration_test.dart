import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/data/repositories/platinum_card_repository.dart';
import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/state/platinum_card_providers.dart';
import 'package:statusxp/ui/screens/platinum_cards_screen.dart';
import 'package:statusxp/ui/widgets/platinum_celebration_host.dart';
import '../platinum_card_test.dart' show fixture;

class FakeRepository implements PlatinumCardRepository {
  int acknowledgments = 0;
  @override
  Future<void> acknowledge(String id) async {
    acknowledgments++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'a multi-platinum batch shows one celebration and Later persists acknowledgment',
    (tester) async {
      final repo = FakeRepository();
      final batch = PlatinumCelebration.fromJson({
        'id': 'batch',
        'count': 5,
        'historical': false,
        'items': [fixture()],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platinumCelebrationProvider.overrideWith((ref) async => batch),
            platinumCardRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: PlatinumCelebrationHost(
              child: Scaffold(body: Text('Dashboard')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You added 5 platinums!'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(repo.acknowledgments, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('first import uses historical summary without claiming today', (
    tester,
  ) async {
    final batch = PlatinumCelebration.fromJson({
      'id': 'import',
      'count': 125,
      'historical': true,
      'items': [fixture()],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platinumCelebrationProvider.overrideWith((ref) async => batch),
          platinumCardRepositoryProvider.overrideWithValue(FakeRepository()),
        ],
        child: const MaterialApp(
          home: PlatinumCelebrationHost(child: Scaffold()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your platinum collection is here'), findsOneWidget);
    expect(find.textContaining('earned today'), findsNothing);
  });
  testWidgets(
    'free editor routes AI to Premium and keeps screenshot and cover options free',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PlatinumCardEditor(
              items: [PlatinumCardData.fromJson(fixture())],
            ),
          ),
          GoRoute(
            path: '/premium-subscription',
            builder: (_, _) => const Scaffold(body: Text('Premium offer')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platinumPremiumProvider.overrideWith((ref) async => false),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Game cover'), findsOneWidget);
      expect(find.text('My screenshot'), findsOneWidget);
      await tester.ensureVisible(find.text('AI artwork · Premium'));
      await tester.tap(find.text('AI artwork · Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Premium offer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'collection picker caps selection at four and supports individual sharing',
    (tester) async {
      final items = List.generate(5, (i) {
        final data = fixture();
        data['platform_game_id'] = 'game-$i';
        data['platinum_number'] = i + 1;
        return PlatinumCardData.fromJson(data);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [platinumCardsProvider.overrideWith((ref) async => items)],
          child: const MaterialApp(home: PlatinumCardsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(Checkbox).at(i));
        await tester.pump();
      }
      expect(find.text('4 selected'), findsOneWidget);
      expect(find.text('Create collection card'), findsOneWidget);
      expect(find.byTooltip('Create share card'), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );
}
