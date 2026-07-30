import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/ui/screens/premium_subscription_screen.dart';

void main() {
  group('annual plan value', () {
    test('calculates savings against twelve monthly payments', () {
      expect(annualSavingsPercent(monthlyPrice: 5, annualPrice: 48), 20);
    });

    test('does not advertise savings when annual costs more', () {
      expect(annualSavingsPercent(monthlyPrice: 5, annualPrice: 65), isNull);
    });
  });
}
