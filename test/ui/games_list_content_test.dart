import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Games List Content Tests', () {
    testWidgets('Dashboard embedded games list displays current fixture data', (
      tester,
    ) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Embedded list should show fixture games
      expect(find.text('Elden Ring'), findsOneWidget);
      expect(find.text('Returnal'), findsOneWidget);

      // Completion strings and trophy summary should render
      expect(find.textContaining('100%'), findsAtLeastNWidgets(1));
      expect(find.textContaining('65%'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Platinum 1'), findsAtLeastNWidgets(1));

      // Current dashboard section labels
      expect(find.text('MY GAMES'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });
}
