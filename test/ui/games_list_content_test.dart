import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/main.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/sample_data.dart';

void main() {
  group('Games List Content Tests', () {
    testWidgets('Games list displays sample games and stats correctly', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with provider overrides for test data
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamesProvider.overrideWith((ref) async => sampleGames),
            userStatsProvider.overrideWith((ref) async => sampleStats),
          ],
          child: const StatusXPApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Games screen
      await tester.tap(find.text('View All Games'));
      await tester.pumpAndSettle();

      // Assert that Elden Ring is present
      expect(find.text('Elden Ring'), findsOneWidget);

      // Assert that 100.0% Complete appears for fully completed game
      expect(find.text('100.0% Complete'), findsAtLeastNWidgets(1));

      // Assert that rarity label includes "% of players"
      expect(find.textContaining('% of players'), findsAtLeastNWidgets(1));
      
      // Assert completion percentages are formatted
      expect(find.textContaining('% Complete'), findsAtLeastNWidgets(5));
      
      // Assert that platform badges are visible
      expect(find.text('PS5'), findsAtLeastNWidgets(1));
      expect(find.text('PS4'), findsAtLeastNWidgets(1));
      
      // Assert that PLATINUM badges are shown for completed games
      expect(find.text('PLATINUM'), findsAtLeastNWidgets(1));
      
      // Verify header stats
      expect(find.text('12 Games Tracked'), findsOneWidget);
      expect(find.textContaining('Platinums Earned'), findsOneWidget);
    });
  });
}

