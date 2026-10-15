import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/ui/widgets/platinum_share_card.dart';

Map<String, dynamic> fixture({double? rarity = 0}) => {
  'platform_id': 2,
  'platform_game_id': 'game',
  'platform_achievement_id': '0',
  'game_name': 'DARK SOULS REMASTERED',
  'trophy_name': 'The Dark Soul',
  'player_name': 'DEX-MORGAN',
  'platinum_number': 125,
  'earned_at': '2020-01-02T12:00:00Z',
  'rarity': rarity,
  'notable': [
    {'name': 'Knight’s Honor', 'rarity': 2.8},
  ],
};
void main() {
  test('rarity preserves zero and excludes unknown or invalid rates', () {
    expect(PlatinumCardData.fromJson(fixture()).rarity, 0);
    for (final rate in [null, -1.0, 101.0, double.nan]) {
      expect(PlatinumCardData.fromJson(fixture(rarity: rate)).rarity, isNull);
    }
  });
  test(
    'historical discovery uses collection language rather than earned today',
    () {
      final batch = PlatinumCelebration.fromJson({
        'id': 'test',
        'count': 200,
        'historical': true,
        'items': [fixture()],
      });
      expect(batch.title, 'Your platinum collection is here');
      expect(batch.count, 200);
      expect(batch.items.single.earnedAt!.year, 2020);
    },
  );
  testWidgets(
    'single card includes logo, real date and optional rarity without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatinumShareCard(
              items: [PlatinumCardData.fromJson(fixture())],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('#125'), findsOneWidget);
      expect(find.textContaining('2020'), findsOneWidget);
      expect(find.textContaining('0.0%'), findsOneWidget);
      expect(find.text('NOTABLE TROPHIES'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'assets/images/app_icon.png',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'four long game titles fit a collection without suggesting 100 percent DLC completion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = fixture()
        ..['game_name'] =
            'A very long game title with a remastered definitive special edition';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatinumShareCard(
              items: List.generate(4, (_) => PlatinumCardData.fromJson(data)),
              quote:
                  'A long personal message about this wonderful gaming achievement, celebrating the journey and all the memories.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 PLATINUMS'), findsOneWidget);
      expect(find.textContaining('100%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
