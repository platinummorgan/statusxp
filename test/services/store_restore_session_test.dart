import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/services/store_restore_session.dart';

void main() {
  test(
    'restore waits for server delivery instead of store enumeration alone',
    () async {
      final session = StoreRestoreSession();
      final verification = Completer<bool>();
      session.track(verification.future.then(session.recordDelivery));
      var finished = false;
      final result = session.finish().then((value) {
        finished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      verification.complete(true);
      expect(await result, StoreRestoreResult.restored);
    },
  );

  test(
    'empty enumeration does not report restored based on existing premium',
    () async {
      expect(
        await StoreRestoreSession().finish(),
        StoreRestoreResult.noPurchases,
      );
    },
  );

  test('failed verification never reports restore success', () async {
    final session = StoreRestoreSession();
    session.track(Future<void>(() => session.recordDelivery(false)));
    expect(await session.finish(), StoreRestoreResult.verificationFailed);
  });

  test(
    'partial delivery or completion failure remains a retryable failure',
    () async {
      final session = StoreRestoreSession();
      session.recordDelivery(true);
      session.track(Future<void>.error(StateError('finish purchase failed')));
      expect(await session.finish(), StoreRestoreResult.verificationFailed);
    },
  );

  test(
    'batches arriving during verification are included before success',
    () async {
      final session = StoreRestoreSession();
      final first = Completer<void>();
      final second = Completer<void>();
      session.track(first.future);
      var finished = false;
      final result = session.finish().then((value) {
        finished = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      session.track(second.future);
      session.recordDelivery(true);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      session.recordFailure();
      second.complete();
      expect(await result, StoreRestoreResult.verificationFailed);
    },
  );
}
