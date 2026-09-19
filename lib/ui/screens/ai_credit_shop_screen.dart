import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:statusxp/services/ai_credit_service.dart';
import 'package:statusxp/services/store_purchase_attempt.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// The same shop is available from membership and achievement guides.
class AICreditShopScreen extends StatefulWidget {
  const AICreditShopScreen({
    super.key,
    this.subscriptionService,
    this.loadBalance,
  });

  final SubscriptionService? subscriptionService;
  final Future<int> Function()? loadBalance;

  @override
  State<AICreditShopScreen> createState() => _AICreditShopScreenState();
}

class _AICreditShopScreenState extends State<AICreditShopScreen>
    with WidgetsBindingObserver {
  late final SubscriptionService _store;
  bool _loading = true;
  bool _purchasing = false;
  int? _balance;
  String? _message;

  @override
  void initState() {
    super.initState();
    _store = widget.subscriptionService ?? SubscriptionService();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshBalance();
  }

  Future<void> _initialize() async {
    try {
      if (!kIsWeb) await _store.initialize();
    } catch (_) {
      if (mounted) {
        _message =
            'The store could not load. Please reopen this page to retry.';
      }
    }
    await _refreshBalance();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshBalance() async {
    try {
      final balance =
          await (widget.loadBalance?.call() ??
              AICreditService().getPackBalance());
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // A failed read must never be shown as a zero balance.
      if (mounted) setState(() => _balance = null);
    }
  }

  ProductDetails? _product(AIPack pack) {
    final id = switch (pack.type) {
      'small' => SubscriptionService.aiPackSmallId,
      'medium' => SubscriptionService.aiPackMediumId,
      'large' => SubscriptionService.aiPackLargeId,
      _ => '',
    };
    return _store.aiPackProducts.where((p) => p.id == id).firstOrNull;
  }

  Future<void> _purchase(AIPack pack, ProductDetails? product) async {
    if (_purchasing || _store.purchasePending) return;
    setState(() {
      _purchasing = true;
      _message = null;
    });
    try {
      if (kIsWeb) {
        final client = Supabase.instance.client;
        final session = (await client.auth.refreshSession()).session;
        if (session == null) throw StateError('Sign in again.');
        final response = await client.functions.invoke(
          'stripe-ai-pack-checkout',
          body: {'packType': pack.type},
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );
        final url = Uri.parse(response.data['url'] as String);
        if (url.scheme != 'https' ||
            !await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw StateError('Could not open checkout.');
        }
        if (mounted) {
          setState(
            () => _message = 'Complete checkout, then refresh your balance.',
          );
        }
      } else {
        if (product == null) return;
        final result = await _store.purchaseAIPack(product);
        if (!mounted) return;
        setState(
          () => _message = switch (result) {
            StorePurchaseResult.verified => '${pack.credits} AI credits added!',
            StorePurchaseResult.canceled => 'Purchase canceled.',
            StorePurchaseResult.pending =>
              'Payment is pending approval. Credits will arrive after it completes.',
            StorePurchaseResult.unconfirmed =>
              'No purchase confirmation received. Check your store purchase history before trying again.',
            _ => 'The purchase could not be completed. Please try again.',
          },
        );
        if (result == StorePurchaseResult.verified) await _refreshBalance();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not complete checkout. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy AI Credits')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: _store.purchaseActivity,
                builder: (context, child) {
                  final busy = _purchasing || _store.purchasePending;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.auto_awesome, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          _balance == null
                              ? 'Credit balance unavailable'
                              : '$_balance pack credits available',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton.icon(
                          onPressed: _refreshBalance,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh balance'),
                        ),
                        const Text(
                          'One-time credit packs for AI achievement guides. Credits are saved to your StatusXP account.\n\n'
                          'Premium already includes AI guides. Pack credits stay saved while Premium is active. Buying a pack does not increase daily usage limits.',
                        ),
                        const SizedBox(height: 20),
                        for (final pack in AICreditService.availablePacks)
                          Builder(
                            builder: (context) {
                              final product = kIsWeb ? null : _product(pack);
                              final available = kIsWeb || product != null;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '${pack.credits} AI credits',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        key: ValueKey('buy-${pack.type}'),
                                        onPressed: busy || !available
                                            ? null
                                            : () => _purchase(pack, product),
                                        child: Text(
                                          available
                                              ? 'Buy for ${kIsWeb ? '${pack.displayPrice} USD' : product!.price}'
                                              : 'Temporarily unavailable',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        if (busy) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                          const Text(
                            'Waiting for purchase confirmation…',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(_message!, textAlign: TextAlign.center),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
