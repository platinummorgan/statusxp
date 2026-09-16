import 'package:statusxp/services/premium_access.dart';
import 'package:statusxp/services/store_restore_session.dart';
import 'package:statusxp/services/store_purchase_attempt.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/crash_reporting_service.dart';
import 'package:statusxp/utils/supabase_guard.dart';
import 'package:statusxp/utils/statusxp_logger.dart';
import 'package:url_launcher/url_launcher.dart';

@visibleForTesting
bool shouldCompleteStorePurchase({
  required PurchaseStatus status,
  required bool pendingCompletePurchase,
  required bool entitlementDelivered,
}) {
  return pendingCompletePurchase &&
      (status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored) &&
      entitlementDelivered;
}

@visibleForTesting
bool storeEntitlementWasDelivered(Object? responseData) {
  return responseData is Map && responseData['success'] == true;
}

@visibleForTesting
Future<void> finalizeVerifiedStorePurchase({
  required PurchaseStatus status,
  required bool entitlementDelivered,
  required bool pendingCompletePurchase,
  required bool androidConsumable,
  required Future<void> Function() consume,
  required Future<void> Function() complete,
}) async {
  if (!entitlementDelivered ||
      (status != PurchaseStatus.purchased &&
          status != PurchaseStatus.restored)) {
    return;
  }
  if (androidConsumable) {
    // Successful consumption also acknowledges a Google Play consumable.
    await consume();
  } else if (pendingCompletePurchase) {
    await complete();
  }
}

/// Subscription plans available
class SubscriptionPlan {
  final String id;
  final String title;
  final String description;
  final String price;
  final List<String> features;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.features,
  });
}

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.active,
    required this.startedAt,
    required this.expiresAt,
    required this.source,
  });
  final bool active;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? source;
}

@visibleForTesting
String humanizeBillingPeriod(String period, {int cycles = 1}) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period);
  if (match == null) return 'introductory period';
  final amount = (int.tryParse(match.group(1)!) ?? 1) * cycles;
  final unit = switch (match.group(2)) {
    'D' => 'day',
    'W' => 'week',
    'M' => 'month',
    'Y' => 'year',
    _ => 'period',
  };
  return '$amount $unit${amount == 1 ? '' : 's'}';
}

/// Subscription Service for managing premium subscriptions
///
/// Handles:
/// - Purchasing subscriptions via Google Play / App Store
/// - Restoring purchases
/// - Verifying subscription status
/// - Syncing premium status with Supabase
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  SupabaseClient? get _supabase => tryGetSupabaseClient();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initialization;
  Future<StoreRestoreResult>? _restoreInFlight;
  StoreRestoreSession? _restoreSession;

  // Product IDs (configure these in Google Play Console and App Store Connect)
  static const String monthlySubscriptionId = 'statusxp_premium_monthly';

  // AI Pack Product IDs (consumable)
  static const String aiPackSmallId = 'statusxp_ai_pack_small';
  static const String aiPackMediumId = 'statusxp_ai_pack_medium';
  static const String aiPackLargeId = 'statusxp_ai_pack_large';

  // Available subscription plans
  List<ProductDetails> _products = [];
  List<ProductDetails> _aiPackProducts = [];
  bool _isAvailable = false;
  final _purchaseFlow = StorePurchaseFlow();

  List<ProductDetails> get products => _products;
  List<ProductDetails> get aiPackProducts => _aiPackProducts;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchaseFlow.busy;
  Listenable get purchaseActivity => _purchaseFlow;

  /// Initialize the IAP connection and listen for purchase updates
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    // Skip IAP initialization on web
    if (kIsWeb) {
      _isAvailable = false;
      return;
    }

    // Check if IAP is available
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      (purchases) {
        final session = _restoreSession;
        final processing = _onPurchaseUpdate(purchases, session);
        if (session != null) {
          session.track(processing);
        } else {
          unawaited(
            processing.catchError((Object _) {
              _purchaseFlow.fail();
              statusxpLog('Purchase processing will need to be retried');
            }),
          );
        }
      },
      onDone: () {
        _purchaseFlow.fail();
        _subscription?.cancel();
      },
      onError: (Object error) {
        _restoreSession?.recordFailure();
        _purchaseFlow.fail();
        statusxpLog('Purchase stream unavailable');
      },
    );

    // Load products
    await _loadProducts();

    // Check for pending purchases on startup
    await restorePurchases();
  }

  /// Load available subscription products from store
  Future<void> _loadProducts() async {
    if (!_isAvailable) return;

    const Set<String> productIds = {
      monthlySubscriptionId,
      aiPackSmallId,
      aiPackMediumId,
      aiPackLargeId,
    };

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds,
      );

      if (response.error != null) {
        return;
      }

      if (response.productDetails.isEmpty) {
        return;
      }

      // Separate subscription from consumable products
      _products = response.productDetails
          .where((p) => p.id == monthlySubscriptionId)
          .toList();
      _aiPackProducts = response.productDetails
          .where(
            (p) =>
                p.id == aiPackSmallId ||
                p.id == aiPackMediumId ||
                p.id == aiPackLargeId,
          )
          .toList();

      debugPrint(
        'Loaded ${_products.length} subscription(s) and ${_aiPackProducts.length} AI pack(s)',
      );
    } catch (e) {
      statusxpLog('Failed loading IAP products: $e');
    }
  }

  /// Handle purchase updates from the store
  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchases,
    StoreRestoreSession? restoreSession,
  ) async {
    for (final purchase in purchases) {
      final attempt = _purchaseFlow.observe(purchase);
      if (purchase.status == PurchaseStatus.pending) {
        unawaited(_logPurchaseStage(purchase.productID, 'pending'));
      } else {
        var entitlementDelivered = false;

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (purchase.productID == monthlySubscriptionId ||
              _isAIPackProduct(purchase.productID)) {
            entitlementDelivered = await _verifyAndDeliverPurchase(purchase);
            restoreSession?.recordDelivery(entitlementDelivered);
          }
        }

        if (purchase.status == PurchaseStatus.error) {
          restoreSession?.recordFailure();
          unawaited(_logPurchaseStage(purchase.productID, 'store_failed'));
          statusxpLog('Purchase failed: ${purchase.error}');
        }

        // Acknowledge/finish only after the trusted backend has verified the
        // store transaction and delivered the entitlement. Failed deliveries
        // remain pending so the store can retry them.
        try {
          await finalizeVerifiedStorePurchase(
            status: purchase.status,
            pendingCompletePurchase: purchase.pendingCompletePurchase,
            entitlementDelivered: entitlementDelivered,
            androidConsumable:
                !kIsWeb &&
                Platform.isAndroid &&
                _isAIPackProduct(purchase.productID),
            consume: () async {
              final result = await _iap
                  .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                  .consumePurchase(purchase);
              if (result.responseCode != BillingResponse.ok) {
                throw StateError('Google Play consumption must be retried');
              }
            },
            complete: () => _iap.completePurchase(purchase),
          );
        } catch (_) {
          restoreSession?.recordFailure();
          attempt?.complete(StorePurchaseResult.failed);
          statusxpLog('Purchase finalization will need to be retried');
          continue;
        }
        if (purchase.status == PurchaseStatus.purchased) {
          attempt?.complete(
            entitlementDelivered
                ? StorePurchaseResult.verified
                : StorePurchaseResult.failed,
          );
        }
        if (entitlementDelivered) {
          unawaited(
            _logPurchaseStage(purchase.productID, 'entitlement_delivered'),
          );
        }
      }
    }
  }

  /// Check if product ID is an AI pack
  bool _isAIPackProduct(String productId) {
    return productId == aiPackSmallId ||
        productId == aiPackMediumId ||
        productId == aiPackLargeId;
  }

  Future<void> _logPurchaseStage(String productId, String stage) async {
    ProductDetails? product;
    for (final candidate in [..._products, ..._aiPackProducts]) {
      if (candidate.id == productId) {
        product = candidate;
        break;
      }
    }

    await AnalyticsService().logPurchaseFunnel(
      stage: stage,
      productId: productId,
      productType: _isAIPackProduct(productId) ? 'ai_credits' : 'subscription',
      value: product?.rawPrice,
      currency: product?.currencyCode,
    );
  }

  PurchaseParam _purchaseParam(ProductDetails product, String userId) {
    final accountHash = Platform.isAndroid
        ? sha256.convert(utf8.encode(userId)).toString()
        : userId;
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: accountHash,
        offerToken: product.offerToken,
      );
    }
    return PurchaseParam(
      productDetails: product,
      // StoreKit carries this UUID as appAccountToken; Play uses its hash.
      // Verification checks the store's account claim before delivery.
      applicationUserName: accountHash,
    );
  }

  String subscriptionPeriod(ProductDetails product) {
    if (product is! GooglePlayProductDetails ||
        product.subscriptionIndex == null) {
      return 'month';
    }
    final offer = product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!];
    final recurringPhase = offer.pricingPhases.last;
    return recurringPhase.billingPeriod == 'P1Y' ? 'year' : 'month';
  }

  bool isAnnualProduct(ProductDetails product) =>
      subscriptionPeriod(product) == 'year';

  List<PricingPhaseWrapper> _pricingPhases(ProductDetails product) {
    if (product is! GooglePlayProductDetails ||
        product.subscriptionIndex == null) {
      return const [];
    }
    return product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!]
        .pricingPhases;
  }

  bool hasFreeTrial(ProductDetails product) {
    final phases = _pricingPhases(product);
    return phases.length > 1 && phases.first.priceAmountMicros == 0;
  }

  bool hasIntroductoryOffer(ProductDetails product) {
    final phases = _pricingPhases(product);
    return phases.length > 1 &&
        phases.first.priceAmountMicros < phases.last.priceAmountMicros;
  }

  String? introductoryOfferLabel(ProductDetails product) {
    final phases = _pricingPhases(product);
    if (phases.length <= 1) return null;
    final first = phases.first;
    final duration = humanizeBillingPeriod(
      first.billingPeriod,
      cycles: first.billingCycleCount.clamp(1, 1000),
    );
    if (first.priceAmountMicros == 0) return '$duration free';
    if (first.priceAmountMicros < phases.last.priceAmountMicros) {
      return '${first.formattedPrice} for $duration';
    }
    return null;
  }

  String recurringPrice(ProductDetails product) {
    final phases = _pricingPhases(product);
    return phases.isEmpty ? product.price : phases.last.formattedPrice;
  }

  double recurringRawPrice(ProductDetails product) {
    final phases = _pricingPhases(product);
    return phases.isEmpty
        ? product.rawPrice
        : phases.last.priceAmountMicros / 1000000.0;
  }

  /// Verify the receipt with the store on the backend and atomically deliver
  /// the corresponding entitlement. The client never writes premium status or
  /// credit balances directly.
  Future<bool> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    try {
      final supabase = _supabase;
      if (supabase == null || supabase.auth.currentUser == null || kIsWeb) {
        return false;
      }

      final platform = Platform.isAndroid
          ? 'google_play'
          : Platform.isIOS
          ? 'app_store'
          : null;
      if (platform == null) return false;

      final response = await supabase.functions.invoke(
        'verify-store-purchase',
        body: {
          'platform': platform,
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'verificationData': purchase.verificationData.serverVerificationData,
        },
      );
      final success = storeEntitlementWasDelivered(response.data);
      if (!success) {
        statusxpLog('Store purchase verification did not deliver entitlement');
      }
      return success;
    } catch (e, stack) {
      await CrashReportingService.instance.recordError(
        e,
        stack,
        reason: 'Store purchase verification failed',
      );
      statusxpLog('Store purchase verification failed');
      return false;
    }
  }

  /// Purchase a subscription
  Future<StorePurchaseResult> purchaseSubscription(ProductDetails product) =>
      _purchase(product, consumable: false);

  Future<StorePurchaseResult> _purchase(
    ProductDetails product, {
    required bool consumable,
  }) async {
    final userId = _supabase?.auth.currentUser?.id;
    if (!_isAvailable || userId == null) return StorePurchaseResult.notStarted;
    return _purchaseFlow.run(
      productId: product.id,
      launch: () async {
        final param = _purchaseParam(product, userId);
        unawaited(_logPurchaseStage(product.id, 'checkout_started'));
        final started = consumable
            ? await _iap.buyConsumable(
                purchaseParam: param,
                autoConsume: !Platform.isAndroid,
              )
            : await _iap.buyNonConsumable(purchaseParam: param);
        unawaited(
          _logPurchaseStage(
            product.id,
            started ? 'store_flow_started' : 'store_flow_rejected',
          ),
        );
        return started;
      },
    );
  }

  /// Restore previous purchases
  Future<StoreRestoreResult> _restorePurchases() async {
    if (!_isAvailable) return StoreRestoreResult.unavailable;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return StoreRestoreResult.notSignedIn;
    final session = StoreRestoreSession();
    _restoreSession = session;
    try {
      await _iap.restorePurchases();
      final result = await session.finish().timeout(
        const Duration(seconds: 45),
        onTimeout: () => StoreRestoreResult.verificationFailed,
      );
      if (_supabase?.auth.currentUser?.id != userId) {
        return StoreRestoreResult.notSignedIn;
      }
      return result;
    } catch (_) {
      return StoreRestoreResult.verificationFailed;
    } finally {
      if (identical(_restoreSession, session)) _restoreSession = null;
    }
  }

  /// Public method to restore purchases (called from UI)
  Future<StoreRestoreResult> restorePurchases() {
    return _restoreInFlight ??= _restorePurchases().whenComplete(() {
      _restoreInFlight = null;
    });
  }

  /// Check if user has active premium subscription
  Future<bool> isPremiumActive() async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        return false;
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await readPremiumEntitlement(supabase);

      return supabase.auth.currentUser?.id == userId &&
          hasActivePremium(response);
    } catch (e) {
      return false;
    }
  }

  Future<PremiumEntitlement?> getPremiumEntitlement() async {
    try {
      final supabase = _supabase;
      final userId = supabase?.auth.currentUser?.id;
      if (supabase == null || userId == null) return null;
      final response = await readPremiumEntitlement(supabase);
      if (response == null || supabase.auth.currentUser?.id != userId) {
        return null;
      }
      return PremiumEntitlement(
        active: hasActivePremium(response),
        startedAt: DateTime.tryParse(
          response['premium_since']?.toString() ?? '',
        ),
        expiresAt: DateTime.tryParse(
          response['premium_expires_at']?.toString() ?? '',
        ),
        source: response['premium_source']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Cancel subscription (redirects to store management)
  Future<void> manageSubscription() async {
    try {
      // Web doesn't have platform-specific subscription management
      if (kIsWeb) {
        // Could open a web URL for subscription management
        return;
      }

      if (Platform.isAndroid) {
        // Open Google Play subscriptions page
        final uri = Uri.parse(
          'https://play.google.com/store/account/subscriptions',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          statusxpLog('Could not launch Google Play subscriptions URL');
        }
      } else if (Platform.isIOS) {
        // Open App Store subscriptions page
        final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          statusxpLog('Could not launch App Store subscriptions URL');
        }
      }
    } catch (e) {
      statusxpLog('Failed opening subscription management: $e');
    }
  }

  /// Get subscription plan info
  SubscriptionPlan get premiumPlan => SubscriptionPlan(
    id: monthlySubscriptionId,
    title: 'StatusXP Premium',
    description: 'Monthly Subscription',
    price: _products.isNotEmpty ? _products[0].price : '\$4.99',
    features: [
      '📊 Premium Analytics Dashboard',
      'AI Achievement Guides (daily limits apply)',
      '⚡ Faster Sync Cooldowns',
      '🎯 12 PSN syncs/day (vs 3 free)',
      '⏱️ 30min PSN cooldown (vs 2hr free)',
      '🎮 15min Xbox/Steam cooldown (vs 1hr free)',
      '💎 Premium Badge',
      '🚀 Priority Support',
      '❤️ Support Development',
    ],
  );

  /// Purchase an AI credit pack (consumable)
  Future<StorePurchaseResult> purchaseAIPack(ProductDetails product) =>
      _purchase(product, consumable: true);

  /// Get AI pack details by product ID
  Map<String, dynamic>? getAIPackDetails(String productId) {
    switch (productId) {
      case aiPackSmallId:
        return {'type': 'small', 'credits': 20, 'price': 1.99};
      case aiPackMediumId:
        return {'type': 'medium', 'credits': 60, 'price': 4.99};
      case aiPackLargeId:
        return {'type': 'large', 'credits': 150, 'price': 9.99};
      default:
        return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _purchaseFlow.fail();
    _subscription?.cancel();
    _subscription = null;
    _initialization = null;
  }
}
