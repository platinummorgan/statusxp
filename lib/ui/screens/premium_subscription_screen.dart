import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _initialize();
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
            onPressed: () => _subscriptionService.manageSubscription(),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          const Text(
            'Cancel anytime',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(SubscriptionPlan plan) {
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
    return const Text(
      'Subscription renews automatically unless cancelled.\n'
      'Managed through your Google Play or App Store account.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: textMuted,
      ),
    );
  }
}
