import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/screens/markdown_viewer_screen.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium Subscription Screen
/// 
/// Shows subscription benefits and allows users to subscribe to Premium
class PremiumSubscriptionScreen extends ConsumerStatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  ConsumerState<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends ConsumerState<PremiumSubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isProcessingStripe = false;

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
    setState(() {
      _isPremium = isPremium;
      _isLoading = false;
    });
  }

  Future<void> _subscribeToPremium() async {
    // Handle web Stripe payments
    if (kIsWeb) {
      await _subscribeWithStripe();
      return;
    }

    // Handle mobile in-app purchases
    if (_subscriptionService.products.isEmpty) {
      _showError('Premium subscription not available at the moment');
      return;
    }

    setState(() => _isLoading = true);

    final product = _subscriptionService.products.first;
    final success = await _subscriptionService.purchaseSubscription(product);

    if (success) {
      // Wait a moment for purchase to process
      await Future.delayed(const Duration(seconds: 2));
      final isPremium = await _subscriptionService.isPremiumActive();
      
      setState(() {
        _isPremium = isPremium;
        _isLoading = false;
      });

      if (_isPremium && mounted) {
        _showSuccess('Welcome to Premium! 🎉');
      }
    } else {
      setState(() => _isLoading = false);
    }
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
      print('Stripe checkout error: $e');
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
      print('Error opening billing portal: $e');
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
      SnackBar(
        content: Text(message),
        backgroundColor: accentWarning,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accentSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _subscriptionService.premiumPlan;

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'STATUSXP PREMIUM',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accentPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_isPremium) _buildPremiumActiveCard(),
                  if (!_isPremium) ...[
                    _buildHeroSection(),
                    const SizedBox(height: 32),
                    _buildFeaturesGrid(plan.features),
                    const SizedBox(height: 32),
                    _buildPricingCard(plan),
                    const SizedBox(height: 24),
                    _buildSubscribeButton(plan),
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
            accentPrimary.withOpacity(0.2),
            accentSecondary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPrimary.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.stars,
            size: 64,
            color: accentPrimary,
          ),
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
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: kIsWeb ? _manageStripeSubscription : () => _subscriptionService.manageSubscription(),
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
            accentPrimary.withOpacity(0.1),
            accentSecondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPrimary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accentPrimary.withOpacity(0.3),
                  accentSecondary.withOpacity(0.3),
                ],
              ),
            ),
            child: const Icon(
              Icons.diamond,
              size: 48,
              color: accentPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock Your Full Potential',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get unlimited AI guides and faster syncs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
            ),
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
            border: Border.all(
              color: accentPrimary.withOpacity(0.2),
            ),
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

  Widget _buildPricingCard(SubscriptionPlan plan) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPrimary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentPrimary.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            plan.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Auto-Renewable Monthly Subscription',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.price,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: accentPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '/month',
                  style: TextStyle(
                    fontSize: 16,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Subscription automatically renews monthly.\nCancel anytime from your account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(SubscriptionPlan plan) {
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
    }

    // Mobile app subscribe button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _subscriptionService.purchasePending ? null : _subscribeToPremium,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: backgroundDark,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _subscriptionService.purchasePending
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: backgroundDark,
                ),
              )
            : const Text(
                'Subscribe Now',
                style: TextStyle(
                  fontSize: 18,
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
        style: TextStyle(
          color: accentPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'Subscription renews automatically unless cancelled.\n'
          'Managed through your Google Play or App Store account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _buildLinkButton(
              'Terms of Use',
              'TERMS_OF_SERVICE.md',
            ),
            const Text(
              '•',
              style: TextStyle(color: textMuted),
            ),
            _buildLinkButton(
              'Privacy Policy',
              'PRIVACY.md',
            ),
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
        builder: (context) => MarkdownViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }
}
