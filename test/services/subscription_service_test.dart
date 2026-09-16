import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:statusxp/services/subscription_service.dart';

void main() {
  group('verified consumable finalization', () {
    test(
      'failed delivery does not consume or acknowledge a purchase',
      () async {
        final calls = <String>[];
        await finalizeVerifiedStorePurchase(
          status: PurchaseStatus.purchased,
          entitlementDelivered: false,
          pendingCompletePurchase: true,
          androidConsumable: true,
          consume: () async {
            calls.add('consume');
          },
          complete: () async {
            calls.add('complete');
          },
        );
        expect(calls, isEmpty);
      },
    );
    test(
      'verified Android consumables use consumption without a second acknowledgement',
      () async {
        final calls = <String>[];
        await finalizeVerifiedStorePurchase(
          status: PurchaseStatus.restored,
          entitlementDelivered: true,
          pendingCompletePurchase: false,
          androidConsumable: true,
          consume: () async {
            calls.add('consume');
          },
          complete: () async {
            calls.add('complete');
          },
        );
        expect(calls, ['consume']);
      },
    );
    test(
      'consumption failure propagates for retry instead of completing the purchase',
      () async {
        var completed = false;
        await expectLater(
          finalizeVerifiedStorePurchase(
            status: PurchaseStatus.purchased,
            entitlementDelivered: true,
            pendingCompletePurchase: true,
            androidConsumable: true,
            consume: () async {
              throw StateError('offline');
            },
            complete: () async {
              completed = true;
            },
          ),
          throwsStateError,
        );
        expect(completed, isFalse);
      },
    );
    test(
      'verified iOS purchases and subscriptions retain normal completion',
      () async {
        var completed = false;
        await finalizeVerifiedStorePurchase(
          status: PurchaseStatus.purchased,
          entitlementDelivered: true,
          pendingCompletePurchase: true,
          androidConsumable: false,
          consume: () async {
            fail('Not a Google consumable');
          },
          complete: () async {
            completed = true;
          },
        );
        expect(completed, isTrue);
      },
    );
  });
  group('subscription offer copy', () {
    test('humanizes Google Play trial periods', () {
      expect(humanizeBillingPeriod('P7D'), '7 days');
      expect(humanizeBillingPeriod('P1W', cycles: 2), '2 weeks');
      expect(humanizeBillingPeriod('P1M'), '1 month');
    });

    test('falls back safely for an unknown billing period', () {
      expect(humanizeBillingPeriod('unknown'), 'introductory period');
    });
  });

  group('store purchase completion policy', () {
    test('completes a purchased item after entitlement delivery', () {
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
          entitlementDelivered: true,
        ),
        isTrue,
      );
    });

    test('does not complete when backend verification fails', () {
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
          entitlementDelivered: false,
        ),
        isFalse,
      );
    });

    test('does not complete pending or failed purchases', () {
      for (final status in [PurchaseStatus.pending, PurchaseStatus.error]) {
        expect(
          shouldCompleteStorePurchase(
            status: status,
            pendingCompletePurchase: true,
            entitlementDelivered: true,
          ),
          isFalse,
        );
      }
    });

    test('restored subscriptions still require backend delivery', () {
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.restored,
          pendingCompletePurchase: true,
          entitlementDelivered: false,
        ),
        isFalse,
      );
    });

    test('successful duplicate delivery is safe to acknowledge', () {
      final delivered = storeEntitlementWasDelivered({
        'success': true,
        'already_processed': true,
      });

      expect(delivered, isTrue);
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
          entitlementDelivered: delivered,
        ),
        isTrue,
      );
    });

    test('invalid receipt response remains unacknowledged', () {
      final delivered = storeEntitlementWasDelivered({
        'success': false,
        'error': 'invalid receipt',
      });

      expect(delivered, isFalse);
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.purchased,
          pendingCompletePurchase: true,
          entitlementDelivered: delivered,
        ),
        isFalse,
      );
    });

    test('backend outage response remains available for retry', () {
      final delivered = storeEntitlementWasDelivered(null);

      expect(delivered, isFalse);
      expect(
        shouldCompleteStorePurchase(
          status: PurchaseStatus.restored,
          pendingCompletePurchase: true,
          entitlementDelivered: delivered,
        ),
        isFalse,
      );
    });

    test('malformed backend success values are rejected', () {
      expect(storeEntitlementWasDelivered({'success': 'true'}), isFalse);
      expect(storeEntitlementWasDelivered(<String, dynamic>{}), isFalse);
      expect(storeEntitlementWasDelivered('success'), isFalse);
    });
  });
}
