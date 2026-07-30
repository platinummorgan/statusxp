import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
import 'package:statusxp/ui/screens/first_sync_onboarding_screen.dart';

void main() {
  testWidgets('shows direct platform choices and connected state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectedPlatformsProvider.overrideWith((ref) async => {'psn'}),
        ],
        child: const MaterialApp(home: FirstSyncOnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('See your gaming story come alive'), findsOneWidget);
    expect(find.text('PlayStation'), findsOneWidget);
    expect(find.text('Xbox'), findsOneWidget);
    expect(find.text('SYNC'), findsOneWidget);
    expect(find.text('CONNECT'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Steam'),
      250,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Steam'), findsOneWidget);
    expect(find.text('CONNECT'), findsWidgets);
  });
}
