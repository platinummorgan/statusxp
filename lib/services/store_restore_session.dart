import 'dart:async';

enum StoreRestoreResult {
  restored,
  noPurchases,
  verificationFailed,
  unavailable,
  notSignedIn,
}

/// Tracks this restore's deliveries, independently of existing premium access.
class StoreRestoreSession {
  final List<Future<void>> _batches = [];
  int _delivered = 0;
  bool _failed = false;

  void recordDelivery(bool delivered) {
    if (delivered) {
      _delivered++;
    } else {
      _failed = true;
    }
  }

  void recordFailure() => _failed = true;

  void track(Future<void> batch) {
    _batches.add(batch.catchError((Object _) => recordFailure()));
  }

  Future<StoreRestoreResult> finish() async {
    // Store adapters emit purchaseStream batches before completing enumeration.
    // Flush their asynchronous stream callbacks, then await server delivery.
    var completed = 0;
    do {
      await Future<void>.delayed(Duration.zero);
      final pending = _batches.skip(completed).toList();
      completed = _batches.length;
      await Future.wait(pending);
    } while (completed != _batches.length);
    if (_failed) return StoreRestoreResult.verificationFailed;
    return _delivered > 0
        ? StoreRestoreResult.restored
        : StoreRestoreResult.noPurchases;
  }
}
