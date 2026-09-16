import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:statusxp/services/store_purchase_attempt.dart';

PurchaseDetails update(PurchaseStatus status, {String product = 'premium'}) =>
    PurchaseDetails(
      productID: product,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    );

void main() {
  test(
    'opening checkout is not a purchase; blank Play cancellation clears busy',
    () async {
      final flow = StorePurchaseFlow();
      var finished = false;
      final result = flow.run(productId: 'premium', launch: () async => true);
      unawaited(result.then((_) => finished = true));
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(flow.busy, isTrue);
      flow.observe(update(PurchaseStatus.canceled, product: ''));
      expect(await result, StorePurchaseResult.canceled);
      expect(flow.busy, isFalse);
      final retry = flow.run(productId: 'premium', launch: () async => true);
      flow.observe(update(PurchaseStatus.canceled));
      expect(await retry, StorePurchaseResult.canceled);
    },
  );

  test('cancellation before launch returns finishes immediately', () async {
    final flow = StorePurchaseFlow();
    final launch = Completer<bool>();
    final result = flow.run(productId: 'premium', launch: () => launch.future);
    flow.observe(update(PurchaseStatus.canceled, product: ''));
    expect(await result, StorePurchaseResult.canceled);
    expect(flow.busy, isFalse);
    launch.complete(true);
  });

  test(
    'store purchase alone waits for backend delivery and finalization',
    () async {
      final flow = StorePurchaseFlow();
      var finished = false;
      final result = flow.run(productId: 'premium', launch: () async => true);
      unawaited(result.then((_) => finished = true));
      final attempt = flow.observe(update(PurchaseStatus.purchased));
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(flow.busy, isTrue);
      attempt!.complete(StorePurchaseResult.verified);
      expect(await result, StorePurchaseResult.verified);
      expect(flow.busy, isFalse);
    },
  );

  test('failed verification or finalization reports failure', () async {
    final flow = StorePurchaseFlow();
    final result = flow.run(productId: 'premium', launch: () async => true);
    flow
        .observe(update(PurchaseStatus.purchased))!
        .complete(StorePurchaseResult.failed);
    expect(await result, StorePurchaseResult.failed);
    expect(flow.busy, isFalse);
  });

  test('restores and unrelated products cannot finish a checkout', () async {
    final flow = StorePurchaseFlow();
    final result = flow.run(productId: 'premium', launch: () async => true);
    expect(flow.observe(update(PurchaseStatus.restored)), isNull);
    expect(
      flow.observe(update(PurchaseStatus.purchased, product: 'credits')),
      isNull,
    );
    expect(
      flow.observe(update(PurchaseStatus.canceled, product: 'credits')),
      isNull,
    );
    expect(flow.busy, isTrue);
    flow.observe(update(PurchaseStatus.canceled));
    expect(await result, StorePurchaseResult.canceled);
  });

  test(
    'store pending is distinct from success and stops the busy state',
    () async {
      final flow = StorePurchaseFlow();
      final result = flow.run(productId: 'premium', launch: () async => true);
      flow.observe(update(PurchaseStatus.pending));
      expect(await result, StorePurchaseResult.pending);
      expect(flow.busy, isFalse);
    },
  );

  test('launch rejected and launch error both release checkout', () async {
    final flow = StorePurchaseFlow();
    expect(
      await flow.run(productId: 'premium', launch: () async => false),
      StorePurchaseResult.notStarted,
    );
    expect(flow.busy, isFalse);
    expect(
      await flow.run(
        productId: 'premium',
        launch: () async => throw StateError('offline'),
      ),
      StorePurchaseResult.failed,
    );
    expect(flow.busy, isFalse);
  });

  test('blank store errors and stream failures release checkout', () async {
    final flow = StorePurchaseFlow();
    final first = flow.run(productId: 'premium', launch: () async => true);
    flow.observe(update(PurchaseStatus.error, product: ''));
    expect(await first, StorePurchaseResult.failed);
    final second = flow.run(productId: 'premium', launch: () async => true);
    flow.fail();
    expect(await second, StorePurchaseResult.failed);
    expect(flow.busy, isFalse);
  });

  test(
    'missing callback is unconfirmed, never success, and releases checkout',
    () async {
      final flow = StorePurchaseFlow(timeout: const Duration(milliseconds: 1));
      final launch = Completer<bool>();
      expect(
        await flow.run(productId: 'premium', launch: () => launch.future),
        StorePurchaseResult.unconfirmed,
      );
      expect(flow.busy, isFalse);
      launch.complete(false);
    },
  );

  test(
    'duplicate launch is prevented and late old result cannot finish retry',
    () async {
      final flow = StorePurchaseFlow();
      final first = flow.run(productId: 'premium', launch: () async => true);
      final attempt = flow.observe(update(PurchaseStatus.purchased))!;
      expect(
        await flow.run(
          productId: 'premium',
          launch: () async => throw StateError('must not launch'),
        ),
        StorePurchaseResult.notStarted,
      );
      attempt.complete(StorePurchaseResult.canceled);
      await first;
      final second = flow.run(productId: 'premium', launch: () async => true);
      attempt.complete(StorePurchaseResult.verified);
      expect(flow.busy, isTrue);
      flow.observe(update(PurchaseStatus.canceled));
      expect(await second, StorePurchaseResult.canceled);
    },
  );
}
