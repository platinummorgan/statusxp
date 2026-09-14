import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/game_achievement_section.dart';

void main() {
  testWidgets(
    'inline paging, search, collapse and detail Back preserve state',
    (tester) async {
      const game = GameRef(platformId: 4, platformGameId: 'game');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(
                child: GameAchievementSection(game: game),
              ),
            ),
          ),
          GoRoute(
            path: '/games/steam/game/achievements/:id',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to game'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            gameAchievementListProvider(game).overrideWith(
              (ref) async => List.generate(
                22,
                (i) => {
                  'platform_achievement_id': '$i',
                  'name': 'Trophy $i',
                  'description': 'Description',
                  'earned': i == 0,
                  'metadata': i == 1 ? {'hidden': true} : {},
                  'base_status_xp': 10,
                },
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trophy 0'), findsOneWidget);
      expect(find.text('Trophy 1'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Next achievements'));
      await tester.tap(find.byTooltip('Next achievements'));
      await tester.pumpAndSettle();
      expect(find.text('Trophy 20'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Trophy 21');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Trophy 21',
      );
      await tester.tap(find.text('Trophy 21').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to game'));
      await tester.pumpAndSettle();
      expect(find.text('Trophy 21').last, findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Earned'));
      await tester.pumpAndSettle();
      expect(find.text('Trophy 0'), findsOneWidget);
      expect(find.text('Trophy 2'), findsNothing);
    },
  );
}
