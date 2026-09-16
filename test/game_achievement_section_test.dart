import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/game_achievement_section.dart';
import 'package:statusxp/ui/widgets/game_achievement_card.dart';
import 'package:statusxp/ui/widgets/game_catalog_summary.dart';
import 'package:statusxp/ui/widgets/create_trophy_request_dialog.dart';
import 'package:statusxp/ui/screens/game_overview_screen.dart';
import 'package:statusxp/domain/game_overview.dart';
import 'package:statusxp/services/achievement_guide_service.dart';
import 'package:statusxp/services/ai_credit_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _GuideService extends AchievementGuideService {
  final calls = <List<String?>>[];
  @override
  Stream<String> generateGuide({
    required String gameTitle,
    required String achievementName,
    required String achievementDescription,
    String? platform,
  }) async* {
    calls.add([gameTitle, achievementName, achievementDescription, platform]);
    yield 'Complete the challenge without taking damage.';
  }
}

Map<String, dynamic> trophy(
  String id, {
  bool earned = false,
  Map<String, dynamic> metadata = const {},
}) => {
  'platform_achievement_id': id,
  'name': 'Trophy $id',
  'description': 'Finish the challenge',
  'earned': earned,
  'earned_at': earned ? DateTime.now().toIso8601String() : null,
  'metadata': {'psn_trophy_type': 'gold', ...metadata},
  'base_status_xp': 25,
  'rarity_global': 2.5,
};

AICreditStatus get premiumCredits => AICreditStatus(
  canUse: true,
  source: 'premium',
  remaining: -1,
  packCredits: 10,
  dailyFree: 3,
);

void main() {
  testWidgets(
    'game opens full width at trophies and stays above system navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const game = GameRef(platformId: 1, platformGameId: 'layout');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            gameOverviewProvider(game).overrideWith(
              (ref) async => const GameOverview(
                ref: game,
                name: 'Crimson Desert',
                isOwned: true,
                achievementsTotal: 3,
                achievementsEarned: 2,
                completionPercentage: 66.7,
              ),
            ),
            gameCatalogTotalsProvider(
              game,
            ).overrideWith((ref) async => const GameCatalogTotals(3, 75)),
            gameAchievementListProvider(game).overrideWith(
              (ref) async => List.generate(3, (i) => trophy('$i')),
            ),
            achievementCreditsProvider.overrideWith(
              (ref) async => premiumCredits,
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: 48)),
              child: child!,
            ),
            home: const GameOverviewScreen(gameRef: game),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Crimson Desert'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('YOUR PROGRESS'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('2/3 trophies'), findsOneWidget);
      expect(find.text('1 remaining'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('inline-game-progress')))
            .height,
        lessThan(150),
      );
      expect(find.textContaining('in the catalog'), findsNothing);
      final firstCard = tester.getRect(find.byType(GameAchievementCard).first);
      expect(firstCard.left, closeTo(32, 1));
      expect(firstCard.width, greaterThanOrEqualTo(324));
      expect(firstCard.top, lessThan(390));
      expect(
        tester.getBottomRight(find.byType(SingleChildScrollView)).dy,
        closeTo(796, 1),
      );
      await tester.tap(find.byTooltip('Search achievements'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Trophy 2');
      await tester.pumpAndSettle();
      expect(find.text('Trophy 0'), findsNothing);
      expect(find.text('Trophy 2').last, findsOneWidget);
      await tester.tap(find.byTooltip('Game options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game details'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('YOUR PROGRESS'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close game details'));
      await tester.pumpAndSettle();
      expect(find.text('Trophy 2').last, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'catalog loading preserves artwork and earned dates across pages',
    () async {
      const game = GameRef(platformId: 1, platformGameId: 'game');
      var catalogReads = 0;
      final client = SupabaseClient(
        'https://test.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['platform_id'], 'eq.1');
          expect(request.url.queryParameters['platform_game_id'], 'eq.game');
          final isCatalog = request.url.path.endsWith('/achievements');
          final fields = request.url.queryParameters['select']!;
          late List<Map<String, dynamic>> rows;
          if (isCatalog) {
            expect(fields, contains('icon_url'));
            expect(fields, contains('rarity_global'));
            rows = catalogReads++ == 0
                ? List.generate(500, (i) => trophy('$i'))
                : [
                    {
                      ...trophy('last'),
                      'icon_url': 'https://test.invalid/icon.png',
                    },
                  ];
          } else {
            expect(request.url.queryParameters['user_id'], 'eq.user');
            expect(fields, contains('earned_at'));
            rows = [
              {
                'platform_achievement_id': 'last',
                'earned_at': '2026-09-15T10:00:00Z',
              },
            ];
          }
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user'),
          supabaseClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      final rows = await container.read(
        gameAchievementListProvider(game).future,
      );
      expect(rows, hasLength(501));
      expect(rows.last['earned'], true);
      expect(rows.last['earned_at'], '2026-09-15T10:00:00Z');
      expect(rows.last['icon_url'], 'https://test.invalid/icon.png');
      expect(catalogReads, 2);
    },
  );
  testWidgets(
    'normal game overview retains trophy details, AI guide and co-op actions',
    (tester) async {
      const game = GameRef(platformId: 1, platformGameId: 'test-game');
      final guide = _GuideService();
      var allowanceReads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            gameOverviewProvider(game).overrideWith(
              (ref) async => const GameOverview(
                ref: game,
                name: 'The Actual Game',
                isOwned: true,
                achievementsTotal: 2,
                achievementsEarned: 1,
              ),
            ),
            gameCatalogTotalsProvider(
              game,
            ).overrideWith((ref) async => const GameCatalogTotals(2, 50)),
            gameAchievementListProvider(game).overrideWith(
              (ref) async => [trophy('1'), trophy('2', earned: true)],
            ),
            achievementCreditsProvider.overrideWith((ref) async {
              allowanceReads++;
              return premiumCredits;
            }),
            achievementGuideServiceProvider.overrideWithValue(guide),
          ],
          child: const MaterialApp(home: GameOverviewScreen(gameRef: game)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GOLD'), findsNWidgets(2));
      expect(find.text('2.5% • VERY RARE'), findsNWidgets(2));
      expect(find.text('25.0 XP'), findsNWidgets(2));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tips/Comments'), findsNWidgets(2));
      expect(find.text('Find Partner'), findsOneWidget);
      expect(allowanceReads, 1);
      await tester.ensureVisible(find.text('AI Help').first);
      await tester.tap(find.text('AI Help').first);
      await tester.pumpAndSettle();
      expect(find.text('ACHIEVEMENT GUIDE'), findsOneWidget);
      expect(guide.calls, [
        ['The Actual Game', 'Trophy 1', 'Finish the challenge', 'ps5'],
      ]);
      expect(
        find.textContaining('Complete the challenge without taking damage.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find Partner'));
      await tester.tap(find.text('Find Partner'));
      await tester.pumpAndSettle();
      final request = tester.widget<CreateTrophyRequestDialog>(
        find.byType(CreateTrophyRequestDialog),
      );
      expect(request.gameId, 'test-game');
      expect(request.gameTitle, 'The Actual Game');
      expect(request.achievementId, '1');
      expect(request.platform, 'psn');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden trophies keep actions disabled until revealed; DLC groups and native order remain',
    (tester) async {
      const game = GameRef(platformId: 1, platformGameId: 'game');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            achievementCreditsProvider.overrideWith(
              (ref) async => premiumCredits,
            ),
            gameAchievementListProvider(game).overrideWith(
              (ref) async => [
                trophy('10'),
                trophy('2', metadata: {'hidden': true}),
                trophy(
                  '3',
                  metadata: {
                    'trophy_group_id': '001',
                    'dlc_name': 'Expansion One',
                  },
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GameAchievementSection(game: game),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden Achievement'), findsOneWidget);
      final help = find.widgetWithText(TextButton, 'AI Help').first;
      expect(tester.widget<TextButton>(help).onPressed, isNull);
      expect(find.text('Trophy 2'), findsNothing);
      await tester.tap(find.text('Reveal hidden'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(help).onPressed, isNotNull);
      expect(
        tester.getTopLeft(find.text('Trophy 2')).dy,
        lessThan(tester.getTopLeft(find.text('Trophy 10')).dy),
      );
      expect(find.text('Trophy 3'), findsNothing);
      await tester.ensureVisible(find.text('Expansion One'));
      await tester.tap(find.text('Expansion One'));
      await tester.pumpAndSettle();
      expect(find.text('Trophy 3'), findsOneWidget);
    },
  );

  testWidgets(
    'rich cards fit narrow phones with large text and Xbox gamerscore',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const game = GameRef(platformId: 12, platformGameId: 'game');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
            achievementCreditsProvider.overrideWith(
              (ref) async => premiumCredits,
            ),
            gameAchievementListProvider(game).overrideWith(
              (ref) async => [
                trophy(
                  '1',
                  earned: true,
                  metadata: {'psn_trophy_type': null, 'xbox_gamerscore': 100},
                ),
              ],
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: GameAchievementSection(game: game),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100G'), findsOneWidget);
      await tester.ensureVisible(find.text('AI Help'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
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
