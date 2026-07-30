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
  final SupabaseClient? _supabase = tryGetSupabaseClient();

  StreamSubscription<List<PurchaseDetails>>? _subscription;

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
  bool _purchasePending = false;

  List<ProductDetails> get products => _products;
  List<ProductDetails> get aiPackProducts => _aiPackProducts;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;

  /// Initialize the IAP connection and listen for purchase updates
  Future<void> initialize() async {
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
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    // Load products
    await _loadProducts();

    // Check for pending purchases on startup
    await _restorePurchases(silent: true);
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
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
        unawaited(_logPurchaseStage(purchase.productID, 'pending'));
      } else {
        _purchasePending = false;

        var entitlementDelivered = false;

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (purchase.productID == monthlySubscriptionId ||
              _isAIPackProduct(purchase.productID)) {
            entitlementDelivered = await _verifyAndDeliverPurchase(purchase);
          }
        }

        if (purchase.status == PurchaseStatus.error) {
          unawaited(_logPurchaseStage(purchase.productID, 'store_failed'));
          statusxpLog('Purchase failed: ${purchase.error}');
        }

        // Acknowledge/finish only after the trusted backend has verified the
        // store transaction and delivered the entitlement. Failed deliveries
        // remain pending so the store can retry them.
        if (shouldCompleteStorePurchase(
          status: purchase.status,
          pendingCompletePurchase: purchase.pendingCompletePurchase,
          entitlementDelivered: entitlementDelivered,
        )) {
          await _iap.completePurchase(purchase);
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
        : null;
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: accountHash,
        offerToken: product.offerToken,
      );
    }
    return PurchaseParam(
      productDetails: product,
      // Flutter maps applicationUserName to Play's obfuscated account ID.
      // This lets the backend bind new Play purchases to the signed-in user.
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
  Future<bool> purchaseSubscription(ProductDetails product) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      final supabase = _supabase;
      if (supabase == null) {
        return false;
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final purchaseParam = _purchaseParam(product, userId);

      _purchasePending = true;
      unawaited(_logPurchaseStage(product.id, 'checkout_started'));

      // Subscriptions use buyNonConsumable (auto-renewing)
      final bool success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      unawaited(
        _logPurchaseStage(
          product.id,
          success ? 'store_flow_started' : 'store_flow_rejected',
        ),
      );

      return success;
    } catch (e) {
      _purchasePending = false;
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> _restorePurchases({bool silent = false}) async {
    if (!_isAvailable) {
      if (!silent) debugPrint('IAP not available');
      return false;
    }

    try {
      await _iap.restorePurchases();
      if (!silent) debugPrint('Purchases restored');
      return true;
    } catch (e) {
      if (!silent) debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Public method to restore purchases (called from UI)
  Future<bool> restorePurchases() async {
    return _restorePurchases(silent: false);
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

      final response = await supabase
          .from('user_premium_status')
          .select('is_premium')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['is_premium'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<PremiumEntitlement?> getPremiumEntitlement() async {
    try {
      final supabase = _supabase;
      final userId = supabase?.auth.currentUser?.id;
      if (supabase == null || userId == null) return null;
      final response = await supabase
          .from('user_premium_status')
          .select(
            'is_premium, premium_since, premium_expires_at, premium_source',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return PremiumEntitlement(
        active: response['is_premium'] == true,
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
      '∞ Unlimited AI Achievement Guides',
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
  Future<bool> purchaseAIPack(ProductDetails product) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      final supabase = _supabase;
      if (supabase == null) {
        return false;
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final purchaseParam = _purchaseParam(product, userId);

      _purchasePending = true;
      unawaited(_logPurchaseStage(product.id, 'checkout_started'));

      // Consumable purchase
      final bool success = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
      );

      unawaited(
        _logPurchaseStage(
          product.id,
          success ? 'store_flow_started' : 'store_flow_rejected',
        ),
      );

      return success;
    } catch (e) {
      _purchasePending = false;
      return false;
    }
  }

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
    _subscription?.cancel();
  }
}
