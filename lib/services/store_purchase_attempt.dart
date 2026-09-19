import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum StorePurchaseResult {
  verified,
  canceled,
  pending,
  failed,
  notStarted,
  unconfirmed,
}

/// A checkout result comes from store callbacks and delivery, not launching UI.
class StorePurchaseAttempt {
  StorePurchaseAttempt(this.productId);

  final String productId;
  final _result = Completer<StorePurchaseResult>();

  Future<StorePurchaseResult> get result => _result.future;

  bool accepts(PurchaseDetails purchase) {
    // Restoring an older purchase must not complete a new checkout.
    if (purchase.status == PurchaseStatus.restored) return false;
    if (purchase.productID == productId) return true;
    // Play cancellation/error callbacks can have no product or purchase ID.
    return purchase.productID.isEmpty &&
        (purchase.status == PurchaseStatus.canceled ||
            purchase.status == PurchaseStatus.error);
  }

  void complete(StorePurchaseResult result) {
    if (!_result.isCompleted) _result.complete(result);
  }
}

class StorePurchaseFlow extends ChangeNotifier {
  StorePurchaseFlow({this.timeout = const Duration(minutes: 2)});

  final Duration timeout;
  StorePurchaseAttempt? _active;

  bool get busy => _active != null;

  Future<StorePurchaseResult> run({
    required String productId,
    required Future<bool> Function() launch,
  }) async {
    if (busy) return StorePurchaseResult.notStarted;
    final attempt = StorePurchaseAttempt(productId);
    _active = attempt;
    notifyListeners();
    // Subscribe before launching: cancellation can arrive before launch returns.
    unawaited(_launch(attempt, launch));
    try {
      return await attempt.result.timeout(
        timeout,
        onTimeout: () => StorePurchaseResult.unconfirmed,
      );
    } finally {
      if (identical(_active, attempt)) {
        _active = null;
        notifyListeners();
      }
    }
  }

  Future<void> _launch(
    StorePurchaseAttempt attempt,
    Future<bool> Function() launch,
  ) async {
    try {
      if (!await launch()) attempt.complete(StorePurchaseResult.notStarted);
    } catch (_) {
      attempt.complete(StorePurchaseResult.failed);
    }
  }

  StorePurchaseAttempt? observe(PurchaseDetails purchase) {
    final attempt = _active;
    if (attempt == null || !attempt.accepts(purchase)) return null;
    switch (purchase.status) {
      case PurchaseStatus.canceled:
        attempt.complete(StorePurchaseResult.canceled);
      case PurchaseStatus.error:
        attempt.complete(StorePurchaseResult.failed);
      case PurchaseStatus.pending:
        attempt.complete(StorePurchaseResult.pending);
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // The service completes this only after verified delivery/finalization.
        break;
    }
    return attempt;
  }

  void fail() => _active?.complete(StorePurchaseResult.failed);
}
