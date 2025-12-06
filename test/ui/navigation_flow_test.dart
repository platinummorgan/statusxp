import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Navigation Flow Tests', () {
    testWidgets('Dashboard to Games List navigation', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Verify dashboard shows key elements
      expect(find.text('Overview'), findsWidgets);

      // Tap View All Games button
      await tester.tap(find.text('View All Games'));
      await tester.pumpAndSettle();

      // Verify Games screen is visible
      expect(find.text('12 Games Tracked'), findsOneWidget);

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify we're back on dashboard
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('View All Games'), findsOneWidget);
    });

    testWidgets('Dashboard to Status Poster navigation', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Verify dashboard shows key elements
      expect(find.text('Overview'), findsWidgets);

      // Tap View Status Poster button
      await tester.tap(find.text('View Status Poster'));
      await tester.pumpAndSettle();

      // Verify Status Poster screen is visible
      expect(find.text('Status Poster'), findsWidgets);

      // Navigate back using back button
      final backButton = find.byType(BackButton);
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Verify we're back on dashboard
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('View Status Poster'), findsOneWidget);
    });

    testWidgets('Complete navigation cycle', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Start on dashboard
      expect(find.text('Overview'), findsWidgets);

      // Go to Games
      await tester.tap(find.text('View All Games'));
      await tester.pumpAndSettle();
      expect(find.text('12 Games Tracked'), findsOneWidget);

      // Back to dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsWidgets);

      // Go to Status Poster
      await tester.tap(find.text('View Status Poster'));
      await tester.pumpAndSettle();
      expect(find.text('Status Poster'), findsWidgets);

      // Back to dashboard
      final backButton = find.byType(BackButton);
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('About dialog appears from overflow menu', (tester) async {
      // Set realistic phone screen size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Pump the app with test helpers
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      // Find and tap the overflow menu button
      final overflowButton = find.byType(PopupMenuButton<String>);
      expect(overflowButton, findsOneWidget);
      await tester.tap(overflowButton);
      await tester.pumpAndSettle();

      // Verify About StatusXP menu item appears
      expect(find.text('About StatusXP'), findsOneWidget);

      // Tap the About menu item
      await tester.tap(find.text('About StatusXP'));
      await tester.pumpAndSettle();

      // Verify the About dialog appears with expected content
      expect(find.text('StatusXP'), findsWidgets);
      expect(find.textContaining('0.1.0'), findsOneWidget);
      expect(find.textContaining('Prototype'), findsOneWidget);
      expect(find.textContaining('sample data'), findsOneWidget);
    });
  });
}
