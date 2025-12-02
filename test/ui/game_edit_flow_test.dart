import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/main.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/sample_data.dart';

void main() {
  group('Game Edit Flow Tests', () {
    testWidgets('Navigate to game detail screen and edit fields', (tester) async {
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

      // Verify we're on the Games screen
      expect(find.text('12 Games Tracked'), findsOneWidget);

      // Find and tap on Returnal game (verify it's tappable)
      expect(find.text('Returnal'), findsOneWidget);
      await tester.tap(find.text('Returnal'));
      await tester.pumpAndSettle();

      // Verify we're on the detail screen
      expect(find.text('SAVE CHANGES'), findsOneWidget);
      
      // Verify all form fields are present
      expect(find.widgetWithText(TextFormField, 'Game Name'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Has Platinum Trophy'), findsOneWidget);
      
      // Find earned trophies field
      final earnedField = find.ancestor(
        of: find.text('Earned Trophies'),
        matching: find.byType(TextFormField),
      );
      expect(earnedField, findsOneWidget);
      
      // Verify we can edit the field
      await tester.enterText(earnedField, '26');
      await tester.pumpAndSettle();
      
      // Verify the text was entered
      expect(find.text('26'), findsWidgets);
      
      // Go back without saving
      await tester.pageBack();
      await tester.pumpAndSettle();
      
      // Verify we're back on Games screen
      expect(find.text('12 Games Tracked'), findsOneWidget);
    });
  });
}
