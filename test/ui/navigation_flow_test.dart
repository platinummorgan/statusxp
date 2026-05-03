import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Navigation Flow Tests', () {
    testWidgets('Dashboard shell renders expected sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      appRouter.go('/');
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      expect(find.text('StatusXP'), findsWidgets);
      expect(find.text('MY GAMES'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('More menu displays key actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      appRouter.go('/');
      await tester.pumpWidget(getTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('Browse All Games'), findsOneWidget);
      expect(find.text('Status Poster'), findsOneWidget);
      expect(find.text('Seasonal Leaderboards'), findsOneWidget);
    });
  });
}
