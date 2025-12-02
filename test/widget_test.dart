// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:statusxp/main.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/sample_data.dart';

void main() {
  testWidgets('App loads with navigation', (WidgetTester tester) async {
    // Build our app with provider overrides for test data.
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

    // Verify that the dashboard screen loads.
    expect(find.text('StatusXP'), findsOneWidget);
    expect(find.text('Welcome back,'), findsOneWidget);
  });
}
