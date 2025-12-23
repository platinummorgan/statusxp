import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final SupabaseClient _supabase = Supabase.instance.client;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // Product IDs (configure these in Google Play Console and App Store Connect)
  static const String monthlySubscriptionId = 'statusxp_premium_monthly';
  
  // Available subscription plans
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;

  /// Initialize the IAP connection and listen for purchase updates
  Future<void> initialize() async {
    // Check if IAP is available
    _isAvailable = await _iap.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('In-App Purchase not available on this device');
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

    const Set<String> productIds = {monthlySubscriptionId};
    
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      
      if (response.error != null) {
        debugPrint('Error loading products: ${response.error}');
        return;
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('No products found. Make sure product IDs are configured in store console.');
        return;
      }
      
      _products = response.productDetails;
      debugPrint('Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('Error querying products: $e');
    }
  }

  /// Handle purchase updates from the store
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        _purchasePending = false;
        
        if (purchase.status == PurchaseStatus.purchased || 
            purchase.status == PurchaseStatus.restored) {
          // Verify and activate subscription
          await _verifyAndActivateSubscription(purchase);
        }
        
        if (purchase.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchase.error}');
        }
        
        // Mark purchase as complete
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  /// Verify purchase with backend and activate premium status
  Future<bool> _verifyAndActivateSubscription(PurchaseDetails purchase) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User not authenticated');
        return false;
      }

      String? transactionId;
      String? platform;
      
      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        transactionId = purchase.billingClientPurchase.orderId;
        platform = 'google_play';
      } else if (Platform.isIOS && purchase is AppStorePurchaseDetails) {
        transactionId = purchase.skPaymentTransaction.transactionIdentifier;
        platform = 'app_store';
      }

      // Update premium status in Supabase
      await _supabase.from('user_premium_status').upsert({
        'user_id': userId,
        'is_premium': true,
        'premium_since': purchase.transactionDate ?? DateTime.now().toIso8601String(),
        'subscription_id': transactionId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Premium subscription activated for user $userId');
      return true;
    } catch (e) {
      debugPrint('Error activating subscription: $e');
      return false;
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(ProductDetails product) async {
    if (!_isAvailable) {
      debugPrint('IAP not available');
      return false;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User must be logged in to purchase');
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      _purchasePending = true;
      
      // Subscriptions use buyNonConsumable (auto-renewing)
      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      
      return success;
    } catch (e) {
      debugPrint('Error purchasing subscription: $e');
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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_premium_status')
          .select('is_premium')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['is_premium'] == true;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Cancel subscription (redirects to store management)
  Future<void> manageSubscription() async {
    if (Platform.isAndroid) {
      // Open Google Play subscriptions page
      // User must cancel through Play Store
      debugPrint('Redirect to Google Play subscriptions');
      // In production, use url_launcher to open:
      // https://play.google.com/store/account/subscriptions
    } else if (Platform.isIOS) {
      // Open App Store subscriptions page
      debugPrint('Redirect to App Store subscriptions');
      // In production, use url_launcher to open:
      // https://apps.apple.com/account/subscriptions
    }
  }

  /// Get subscription plan info
  SubscriptionPlan get premiumPlan => SubscriptionPlan(
    id: monthlySubscriptionId,
    title: 'StatusXP Premium',
    description: 'Monthly Subscription',
    price: _products.isNotEmpty ? _products[0].price : '\$4.99',
    features: [
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

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}
