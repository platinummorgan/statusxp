import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/services/local_reminder_service.dart';

void main() {
  test('configures Apple notifications without prompting during startup', () {
    final ios = localReminderInitializationSettings.iOS;
    final macOS = localReminderInitializationSettings.macOS;

    expect(ios, isNotNull);
    expect(ios!.requestAlertPermission, isFalse);
    expect(ios.requestBadgePermission, isFalse);
    expect(ios.requestSoundPermission, isFalse);

    expect(macOS, isNotNull);
    expect(macOS!.requestAlertPermission, isFalse);
    expect(macOS.requestBadgePermission, isFalse);
    expect(macOS.requestSoundPermission, isFalse);
  });
}
