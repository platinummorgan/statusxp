import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      
      if (response.error != null) {
        return;
      }
      
      if (response.productDetails.isEmpty) {
        return;
      }
      
      // Separate subscription from consumable products
      _products = response.productDetails.where((p) => p.id == monthlySubscriptionId).toList();
      _aiPackProducts = response.productDetails.where((p) => 
        p.id == aiPackSmallId || p.id == aiPackMediumId || p.id == aiPackLargeId
      ).toList();
      
      debugPrint('Loaded ${_products.length} subscription(s) and ${_aiPackProducts.length} AI pack(s)');
    } catch (e) {
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
          // Check if it's subscription or AI pack
          if (purchase.productID == monthlySubscriptionId) {
            await _verifyAndActivateSubscription(purchase);
          } else if (_isAIPackProduct(purchase.productID)) {
            await _verifyAndGrantAICredits(purchase);
          }
        }
        
        if (purchase.status == PurchaseStatus.error) {
        }
        
        // Mark purchase as complete
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
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

  /// Verify AI pack purchase and grant credits
  Future<bool> _verifyAndGrantAICredits(PurchaseDetails purchase) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final packDetails = getAIPackDetails(purchase.productID);
      if (packDetails == null) {
        return false;
      }

      // Web doesn't support in-app purchases
      if (kIsWeb) return false;

      String? platform;
      if (Platform.isAndroid) {
        platform = 'google_play';
      } else if (Platform.isIOS) {
        platform = 'app_store';
      }

      // Grant AI credits via RPC function
      final response = await _supabase.rpc(
        'add_ai_pack_credits',
        params: {
          'p_user_id': userId,
          'p_pack_type': packDetails['type'],
          'p_credits': packDetails['credits'],
          'p_price': packDetails['price'],
          'p_platform': platform ?? 'unknown',
        },
      );

      final result = response as Map<String, dynamic>;
      final success = result['success'] ?? false;
      
      if (success) {
      } else {
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Verify purchase with backend and activate premium status
  Future<bool> _verifyAndActivateSubscription(PurchaseDetails purchase) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      String? transactionId;
      
      // Web doesn't support purchase completion
      if (kIsWeb) return false;
      
      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        transactionId = purchase.billingClientPurchase.orderId;
      } else if (Platform.isIOS && purchase is AppStorePurchaseDetails) {
        transactionId = purchase.skPaymentTransaction.transactionIdentifier;
      }

      // Update premium status in Supabase
      await _supabase.from('user_premium_status').upsert({
        'user_id': userId,
        'is_premium': true,
        'premium_since': purchase.transactionDate ?? DateTime.now().toIso8601String(),
        'subscription_id': transactionId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(ProductDetails product) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
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
      return false;
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
        final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
        }
      } else if (Platform.isIOS) {
        // Open App Store subscriptions page
        final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
        }
      }
    } catch (e) {
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

  /// Purchase an AI credit pack (consumable)
  Future<bool> purchaseAIPack(ProductDetails product) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      _purchasePending = true;
      
      // Consumable purchase
      final bool success = await _iap.buyConsumable(purchaseParam: purchaseParam);
      
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
