import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/coop_feedback.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/coop_feedback_card.dart';

class FeedbackService extends TrophyHelpService {
  FeedbackService()
    : super(
        SupabaseClient(
          'https://test.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  CoopFeedback? saved;
  bool failLoad = false;
  bool failSave = false;
  int writes = 0;
  Completer<CoopFeedback?>? delayed;
  @override
  Future<CoopFeedback?> getMyFeedback(String requestId) async {
    if (failLoad) throw StateError('offline');
    return delayed?.future ?? saved;
  }

  @override
  Future<void> saveFeedback(String requestId, CoopFeedback feedback) async {
    writes++;
    if (failSave) throw StateError('offline');
    saved = feedback;
  }
}

void main() {
  Future<void> showCard(WidgetTester tester, FeedbackService service) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trophyHelpServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CoopFeedbackCard(requestId: 'request'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'feedback requires an explicit outcome and saves private choices',
    (tester) async {
      final service = FeedbackService();
      await showCard(tester, service);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save feedback'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Your feedback is private and is not shown to other players.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Reached the goal'));
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.tap(find.text('Save feedback'));
      await tester.pumpAndSettle();
      expect(service.saved!.outcome, 'goal_completed');
      expect(service.saved!.teamAgain, true);
      expect(service.writes, 1);
      expect(find.text('Update feedback'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed feedback save preserves choices for retry', (
    tester,
  ) async {
    final service = FeedbackService()..failSave = true;
    await showCard(tester, service);
    await tester.tap(find.text('Made progress'));
    await tester.pump();
    await tester.tap(find.text('Save feedback'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your choices are still here'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Made progress'))
          .selected,
      true,
    );
    service.failSave = false;
    await tester.tap(find.text('Save feedback'));
    await tester.pumpAndSettle();
    expect(service.saved!.outcome, 'made_progress');
    expect(service.saved!.teamAgain, isNull);
  });
  testWidgets('existing feedback loads for editing', (tester) async {
    final service = FeedbackService()
      ..saved = const CoopFeedback(outcome: 'did_not_play', teamAgain: false);
    await showCard(tester, service);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Did not get to play'),
          )
          .selected,
      true,
    );
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No')).selected,
      true,
    );
    expect(find.text('Update feedback'), findsOneWidget);
  });
  testWidgets('load failure offers retry without inventing empty feedback', (
    tester,
  ) async {
    final service = FeedbackService()..failLoad = true;
    await showCard(tester, service);
    expect(find.text('Save feedback'), findsNothing);
    expect(find.text('Retry feedback'), findsOneWidget);
    service.failLoad = false;
    await tester.tap(find.text('Retry feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Save feedback'), findsOneWidget);
  });
}
