import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/achievement_progress.dart';

void main() {
  test('unavailable totals do not display zero or a completion claim', () {
    expect(achievementCountLabel(12, 0), '12/?');
    expect(achievementCompletionLabel(12, 0, 100), 'Unknown');
  });
  test('inconsistent totals remain unknown until reconciled', () {
    expect(achievementCountLabel(12, 10), '12/?');
    expect(achievementCompletionLabel(12, 10, 120), 'Unknown');
  });
  test('known totals keep the normal display', () {
    expect(achievementCountLabel(3, 10), '3/10');
    expect(achievementCompletionLabel(3, 10, 30), '30%');
    expect(achievementCountLabel(0, 10), '0/10');
  });
}
