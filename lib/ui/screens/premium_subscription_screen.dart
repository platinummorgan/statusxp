import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/screens/markdown_viewer_screen.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/premium_activation_checklist.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

@visibleForTesting
int? annualSavingsPercent({
  required double monthlyPrice,
  required double annualPrice,
}) {
  if (monthlyPrice <= 0 || annualPrice <= 0) return null;
  final fullYear = monthlyPrice * 12;
  final saving = ((fullYear - annualPrice) / fullYear * 100).round();
  return saving > 0 ? saving : null;
}

/// Premium Subscription Screen
///
/// Shows subscription benefits and allows users to subscribe to Premium
class PremiumSubscriptionScreen extends ConsumerStatefulWidget {
  const PremiumSubscriptionScreen({this.source = 'direct', super.key});

  final String source;

  @override
  ConsumerState<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState
    extends ConsumerState<PremiumSubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isPurchasing = false;
  bool _isProcessingStripe = false;
  ProductDetails? _selectedSubscriptionProduct;
  PremiumEntitlement? _entitlement;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh premium status when returning to this screen
    _refreshPremiumStatus();
  }

  Future<void> _refreshPremiumStatus() async {
    final isPremium = await _subscriptionService.isPremiumActive();
    if (mounted && isPremium != _isPremium) {
      setState(() {
        _isPremium = isPremium;
      });
    }
  }

  Future<void> _initialize() async {
    await _subscriptionService.initialize();
    final isPremium = await _subscriptionService.isPremiumActive();
    final entitlement = isPremium
        ? await _subscriptionService.getPremiumEntitlement()
        : null;
    if (!mounted) return;
    setState(() {
      _isPremium = isPremium;
      _entitlement = entitlement;
      if (_subscriptionService.products.isNotEmpty) {
        _selectedSubscriptionProduct = _defaultSubscriptionProduct();
      }
      _isLoading = false;
    });
    _logFunnel(isPremium ? 'active_member_view' : 'offer_view');
  }

  ProductDetails _defaultSubscriptionProduct() {
    for (final product in _subscriptionChoices) {
      if (_subscriptionService.isAnnualProduct(product)) return product;
    }
    return _subscriptionChoices.first;
  }

  void _logFunnel(String stage, {ProductDetails? product}) {
    final selected = product ?? _selectedSubscriptionProduct;
    AnalyticsService().logCustomEvent(
      eventName: 'premium_funnel',
      parameters: {
        'stage': stage,
        'source': widget.source,
        'plan': selected == null
            ? (kIsWeb ? 'web' : 'unavailable')
            : _subscriptionService.subscriptionPeriod(selected),
        if (selected != null)
          'price': _subscriptionService.recurringRawPrice(selected),
        if (selected != null)
          'intro_offer': _subscriptionService.hasIntroductoryOffer(selected),
      },
    );
  }

  List<ProductDetails> get _subscriptionChoices {
    final choices = <String, ProductDetails>{};
    for (final product in _subscriptionService.products) {
      final period = _subscriptionService.subscriptionPeriod(product);
      final current = choices[period];
      if (current == null || _offerRank(product) > _offerRank(current)) {
        choices[period] = product;
      }
    }
    return choices.values.toList();
  }

  int _offerRank(ProductDetails product) {
    if (_subscriptionService.hasFreeTrial(product)) return 2;
    if (_subscriptionService.hasIntroductoryOffer(product)) return 1;
    return 0;
  }

  Future<void> _subscribeToPremium() async {
    if (_isPurchasing || _subscriptionService.purchasePending) return;

    // Handle web Stripe payments
    if (kIsWeb) {
      _logFunnel('checkout_start');
      await _subscribeWithStripe();
      return;
    }

    // Handle mobile in-app purchases
    if (_subscriptionService.products.isEmpty) {
      _showError('Premium subscription not available at the moment');
      return;
    }

    setState(() => _isPurchasing = true);

    final product =
        _selectedSubscriptionProduct ?? _subscriptionService.products.first;
    _logFunnel('checkout_start', product: product);
    try {
      final success = await _subscriptionService.purchaseSubscription(product);
      if (!success) {
        _logFunnel('checkout_not_started', product: product);
        _showError('The purchase could not be started. Please try again.');
        return;
      }

      final activated = await _waitForPremiumActivation();
      if (!mounted) return;

      if (activated) {
        _logFunnel('activated', product: product);
        final entitlement = await _subscriptionService.getPremiumEntitlement();
        if (!mounted) return;
        setState(() {
          _isPremium = true;
          _entitlement = entitlement;
        });
        _showSuccess('Welcome to Premium! 🎉');
      } else {
        _logFunnel('activation_pending', product: product);
        _showSuccess(
          'Purchase received and still processing. Premium will activate automatically.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<bool> _waitForPremiumActivation() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (await _subscriptionService.isPremiumActive()) return true;
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> _subscribeWithStripe() async {
    setState(() => _isProcessingStripe = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Call Stripe checkout Edge Function (auth header added automatically)
      final response = await supabase.functions.invoke(
        'stripe-create-checkout',
      );

      if (response.data != null && response.data['url'] != null) {
        final checkoutUrl = response.data['url'] as String;

        // Open Stripe Checkout in browser
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError('Could not open payment page');
        }
      } else {
        _showError('Failed to create checkout session');
      }
    } catch (e) {
      statusxpLog('Stripe checkout error: $e');
      _showError('Failed to start checkout process');
    } finally {
      setState(() => _isProcessingStripe = false);
    }
  }

  Future<void> _manageStripeSubscription() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Refresh session to ensure it's valid
      final sessionResponse = await supabase.auth.refreshSession();
      if (sessionResponse.session == null) {
        _showError('Please sign in again');
        return;
      }

      final response = await supabase.functions.invoke(
        'stripe-customer-portal',
        headers: {
          'Authorization': 'Bearer ${sessionResponse.session!.accessToken}',
        },
      );

      if (response.data != null && response.data['url'] != null) {
        final portalUrl = response.data['url'] as String;
        final uri = Uri.parse(portalUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError('Could not open subscription management');
        }
      } else {
        _showError('Failed to create portal session');
      }
    } catch (e) {
      statusxpLog('Error opening billing portal: $e');
      _showError('Failed to open subscription management');
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    final success = await _subscriptionService.restorePurchases();

    if (success) {
      final isPremium = await _subscriptionService.isPremiumActive();
      setState(() {
        _isPremium = isPremium;
        _isLoading = false;
      });

      if (_isPremium && mounted) {
        _showSuccess('Purchases restored successfully!');
      } else if (mounted) {
        _showError('No active subscriptions found');
      }
    } else {
      setState(() => _isLoading = false);
      _showError('Failed to restore purchases');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: accentWarning),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: accentSuccess),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _subscriptionService.premiumPlan;
    final selectedProduct = _selectedSubscriptionProduct;

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'STATUSXP PREMIUM',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_isPremium) ...[
                    _buildPremiumActiveCard(),
                    const SizedBox(height: 18),
                    if (ref.read(currentUserIdProvider) case final userId?)
                      PremiumActivationChecklist(userId: userId),
                  ],
                  if (!_isPremium) ...[
                    _buildHeroSection(),
                    const SizedBox(height: 18),
                    _buildPersonalizedValue(),
                    const SizedBox(height: 26),
                    _buildFeaturesGrid(plan.features),
                    const SizedBox(height: 26),
                    _buildComparisonCard(),
                    const SizedBox(height: 26),
                    if (!kIsWeb && _subscriptionChoices.length > 1) ...[
                      _buildPlanSelector(),
                      const SizedBox(height: 16),
                    ],
                    _buildPricingCard(plan, selectedProduct),
                    const SizedBox(height: 24),
                    _buildSubscribeButton(plan, selectedProduct),
                    const SizedBox(height: 16),
                    _buildRestoreButton(),
                    const SizedBox(height: 32),
                    _buildFooter(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPremiumActiveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentPrimary.withValues(alpha: 0.2),
            accentSecondary.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPrimary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars, size: 64, color: accentPrimary),
          const SizedBox(height: 16),
          const Text(
            'You\'re Premium! 🎉',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enjoying unlimited features',
            style: TextStyle(fontSize: 16, color: textSecondary),
          ),
          if (_entitlement?.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Current access through ${DateFormat.yMMMd().format(_entitlement!.expiresAt!.toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: kIsWeb
                ? _manageStripeSubscription
                : () => _subscriptionService.manageSubscription(),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentPrimary,
              side: const BorderSide(color: accentPrimary),
            ),
            child: const Text('Manage Subscription'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentPrimary.withValues(alpha: 0.1),
            accentSecondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accentPrimary.withValues(alpha: 0.3),
                  accentSecondary.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: const Icon(Icons.diamond, size: 48, color: accentPrimary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Make Every Achievement Count',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Know what to play next, finish more games, and understand your progress.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(List<String> features) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentPrimary.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              feature,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalizedValue() {
    final stats = ref.watch(dashboardStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();
    final games =
        stats.psnStats.gamesCount +
        stats.xboxStats.gamesCount +
        stats.steamStats.gamesCount;
    final unlocks =
        stats.psnStats.achievementsUnlocked +
        stats.xboxStats.achievementsUnlocked +
        stats.steamStats.achievementsUnlocked;
    if (games == 0 && unlocks == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Text(
            'BUILT AROUND YOUR HISTORY',
            style: TextStyle(
              color: accentPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$games games • $unlocks unlocks • ${stats.totalStatusXP.round()} StatusXP',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Premium turns this history into personalized goals, insights, and smarter next moves.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    const rows = [
      ('Daily syncs', '3', 'Up to 12'),
      ('Sync cooldown', 'Up to 2 hours', 'As low as 15 min'),
      ('AI achievement guides', 'Limited', 'Unlimited'),
      ('Advanced player insights', '—', 'Included'),
      ('Goals & achievement radar', '—', 'Included'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'FREE VS PREMIUM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(flex: 5, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text(
                  'FREE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'PREMIUM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accentPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      row.$1,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: accentPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return SegmentedButton<ProductDetails>(
      segments: _subscriptionChoices.map((product) {
        final annual = _subscriptionService.isAnnualProduct(product);
        return ButtonSegment<ProductDetails>(
          value: product,
          label: Text(annual ? 'Annual' : 'Monthly'),
          icon: Icon(annual ? Icons.savings_outlined : Icons.calendar_month),
        );
      }).toList(),
      selected: {_selectedSubscriptionProduct ?? _subscriptionChoices.first},
      onSelectionChanged: _isPurchasing
          ? null
          : (selection) {
              setState(() => _selectedSubscriptionProduct = selection.first);
              _logFunnel('plan_selected', product: selection.first);
            },
      showSelectedIcon: false,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? backgroundDark
              : Colors.white,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accentPrimary
              : surfaceLight,
        ),
      ),
    );
  }

  Widget _buildPricingCard(
    SubscriptionPlan plan,
    ProductDetails? selectedProduct,
  ) {
    final period = selectedProduct == null
        ? 'month'
        : _subscriptionService.subscriptionPeriod(selectedProduct);
    final price = selectedProduct == null
        ? plan.price
        : _subscriptionService.recurringPrice(selectedProduct);
    final introLabel = selectedProduct == null
        ? null
        : _subscriptionService.introductoryOfferLabel(selectedProduct);
    final annual =
        selectedProduct != null &&
        _subscriptionService.isAnnualProduct(selectedProduct);
    final savings = annual ? _annualSavingsPercent(selectedProduct) : null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPrimary, width: 2),
        boxShadow: [
          BoxShadow(
            color: accentPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          if (annual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accentSuccess,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                savings == null ? 'BEST VALUE' : 'BEST VALUE • SAVE $savings%',
                style: const TextStyle(
                  color: backgroundDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (annual) const SizedBox(height: 12),
          if (introLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: accentPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                introLabel.toUpperCase(),
                style: const TextStyle(
                  color: backgroundDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            plan.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-Renewable ${period == 'year' ? 'Annual' : 'Monthly'} Subscription',
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: accentPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '/$period',
                  style: const TextStyle(fontSize: 16, color: textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${introLabel == null ? '' : 'Offer applies first, then $price/$period.\n'}'
            'Subscription automatically renews every $period. Cancel anytime from your account settings.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  int? _annualSavingsPercent(ProductDetails annual) {
    ProductDetails? monthly;
    for (final product in _subscriptionChoices) {
      if (!_subscriptionService.isAnnualProduct(product)) {
        monthly = product;
        break;
      }
    }
    if (monthly == null ||
        _subscriptionService.recurringRawPrice(monthly) <= 0) {
      return null;
    }
    return annualSavingsPercent(
      monthlyPrice: _subscriptionService.recurringRawPrice(monthly),
      annualPrice: _subscriptionService.recurringRawPrice(annual),
    );
  }

  Widget _buildSubscribeButton(
    SubscriptionPlan plan,
    ProductDetails? selectedProduct,
  ) {
    // Web users get Stripe checkout button
    if (kIsWeb) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessingStripe ? null : _subscribeToPremium,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentPrimary,
            foregroundColor: backgroundDark,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isProcessingStripe
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: backgroundDark,
                  ),
                )
              : const Text(
                  'Subscribe with Card',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      );
    }

    // Mobile app subscribe button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isPurchasing || _subscriptionService.purchasePending
            ? null
            : _subscribeToPremium,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: backgroundDark,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isPurchasing || _subscriptionService.purchasePending
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: backgroundDark,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Finalizing Purchase…',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Text(
                selectedProduct != null &&
                        _subscriptionService.hasFreeTrial(selectedProduct)
                    ? 'Start ${_subscriptionService.introductoryOfferLabel(selectedProduct)}'
                    : 'Subscribe Now • ${selectedProduct == null ? plan.price : _subscriptionService.recurringPrice(selectedProduct)}/${selectedProduct == null ? 'month' : _subscriptionService.subscriptionPeriod(selectedProduct)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    // Hide restore button on web
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: _restorePurchases,
      child: const Text(
        'Restore Purchases',
        style: TextStyle(color: accentPrimary, fontSize: 14),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          '${kIsWeb ? 'Secure card checkout' : 'Secure checkout through Google Play'}. Cancel anytime in your account settings.\n'
          'Your subscription renews automatically unless cancelled.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: textMuted),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _buildLinkButton('Terms of Use', 'TERMS_OF_SERVICE.md'),
            const Text('•', style: TextStyle(color: textMuted)),
            _buildLinkButton('Privacy Policy', 'PRIVACY.md'),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkButton(String label, String assetPath) {
    return InkWell(
      onTap: () => _openDocument(label, assetPath),
      child: Text(
        label,
        style: const TextStyle(
          color: accentPrimary,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _openDocument(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MarkdownViewerScreen(title: title, assetPath: assetPath),
      ),
    );
  }
}
