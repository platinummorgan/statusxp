import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Game Edit Flow Tests', () {
    testWidgets('More menu exposes key game destinations', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Open dashboard "More" menu
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      // Verify core navigation options exist
      expect(find.text('Browse All Games'), findsOneWidget);
      expect(find.text('Status Poster'), findsOneWidget);
      expect(find.text('All-Time Leaderboards'), findsOneWidget);
    });
  });
}
