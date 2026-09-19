import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/ui/widgets/coop_reschedule_dialog.dart';
import 'package:statusxp/ui/widgets/coop_session_summary.dart';

TrophyHelpRequest request(DateTime start) => TrophyHelpRequest(
  id: 'request',
  userId: 'owner',
  gameId: 'game',
  gameTitle: 'Game',
  achievementId: 'goal',
  achievementName: 'Goal',
  platform: 'psn',
  status: 'assigned',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  scheduledAt: start,
  scheduleRevision: 2,
  scheduleChangedAt: DateTime.utc(2026, 9, 13),
);

void main() {
  Future<void> showEditor(
    WidgetTester tester,
    DateTime start,
    Future<void> Function(DateTime?) save,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) =>
                    CoopRescheduleDialog(request: request(start), onSave: save),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets('past timing cannot save; flexible timing can', (tester) async {
    var writes = 0;
    DateTime? saved = DateTime.utc(2000);
    await showEditor(tester, DateTime.utc(2000), (start) async {
      writes++;
      saved = start;
    });
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(
      find.text('Choose a future time or use flexible timing.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use flexible timing'));
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(saved, isNull);
    expect(find.byType(CoopRescheduleDialog), findsNothing);
  });

  testWidgets('failed save preserves timing and allows retry', (tester) async {
    final start = DateTime.now().add(const Duration(days: 2));
    var writes = 0;
    await showEditor(tester, start, (value) async {
      expect(value, start);
      if (++writes == 1) throw StateError('offline');
    });
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save.'), findsOneWidget);
    expect(find.text(coopLocalStart(start)), findsOneWidget);
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(find.byType(CoopRescheduleDialog), findsNothing);
  });

  testWidgets('schedule changes survive model round trip and are visible', (
    tester,
  ) async {
    final restored = TrophyHelpRequest.fromJson(
      request(DateTime.utc(2030)).toJson(),
    ).copyWith(status: 'open');
    expect(restored.scheduleRevision, 2);
    expect(restored.scheduleChangedAt, DateTime.utc(2026, 9, 13));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CoopSessionSummary(request: restored)),
      ),
    );
    expect(find.textContaining('Timing updated'), findsOneWidget);
  });
}
