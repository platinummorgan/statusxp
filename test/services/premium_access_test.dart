import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/services/premium_access.dart';

void main() {
  final now = DateTime.utc(2026, 9, 12, 12);
  test('expiry overrides a stale active flag at the exact boundary', () {
    for (final expiry in ['2026-09-12T11:59:59Z', '2026-09-12T12:00:00Z']) {
      expect(
        hasActivePremium({
          'is_premium': true,
          'premium_expires_at': expiry,
        }, now: now),
        isFalse,
      );
    }
    expect(
      hasActivePremium({
        'is_premium': true,
        'premium_expires_at': '2026-09-12T12:00:01Z',
      }, now: now),
      isTrue,
    );
  });
  test('revoked access cannot be restored by a future expiry', () {
    expect(
      hasActivePremium({
        'is_premium': false,
        'premium_expires_at': '2027-01-01T00:00:00Z',
      }, now: now),
      isFalse,
    );
    expect(hasActivePremium(null, now: now), isFalse);
  });
  test(
    'malformed expiry fails closed while null preserves non-expiring grants',
    () {
      for (final expiry in ['', 'invalid', 123]) {
        expect(
          hasActivePremium({
            'is_premium': true,
            'premium_expires_at': expiry,
          }, now: now),
          isFalse,
        );
      }
      expect(
        hasActivePremium({
          'is_premium': true,
          'premium_expires_at': null,
        }, now: now),
        isTrue,
      );
    },
  );
  test('expiry compares instants across timezone offsets', () {
    expect(
      hasActivePremium({
        'is_premium': true,
        'premium_expires_at': '2026-09-12T08:00:00-04:00',
      }, now: now),
      isFalse,
    );
  });
}
