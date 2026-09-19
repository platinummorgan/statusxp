import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:statusxp/services/store_purchase_attempt.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/ui/screens/premium_subscription_screen.dart';
import 'package:statusxp/ui/screens/ai_credit_shop_screen.dart';
import 'package:statusxp/state/statusxp_providers.dart';

void main() {
  testWidgets('active Premium members can open the AI credit shop', (
    tester,
  ) async {
    final service = CheckoutTestService(premium: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: PremiumSubscriptionScreen(subscriptionService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're Premium! 🎉"), findsOneWidget);
    final shop = find.text('Buy AI Credits');
    await tester.ensureVisible(shop);
    await tester.tap(shop);
    await tester.pumpAndSettle();
    expect(find.byType(AICreditShopScreen), findsOneWidget);
    expect(find.text('Already Premium'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reopened membership page reacts when an existing checkout is canceled',
    (tester) async {
      final service = CheckoutTestService();
      final purchase = service.purchaseSubscription(service.product);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PremiumSubscriptionScreen(subscriptionService: service),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Finalizing Purchase…'), findsOneWidget);
      service.flow.observe(
        PurchaseDetails(
          productID: '',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'test',
          ),
          transactionDate: null,
          status: PurchaseStatus.canceled,
        ),
      );
      expect(await purchase, StorePurchaseResult.canceled);
      await tester.pumpAndSettle();
      expect(find.text('Finalizing Purchase…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Welcome to Premium'), findsNothing);
    },
  );
  for (final status in [
    PurchaseStatus.canceled,
    PurchaseStatus.error,
    PurchaseStatus.pending,
  ]) {
    testWidgets('$status clears the spinner without announcing success', (
      tester,
    ) async {
      final service = CheckoutTestService();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PremiumSubscriptionScreen(subscriptionService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final subscribe = find.textContaining('Subscribe Now');
      await tester.ensureVisible(subscribe);
      await tester.tap(subscribe);
      await tester.pump();
      expect(find.text('Finalizing Purchase…'), findsOneWidget);
      expect(find.textContaining('Welcome to Premium'), findsNothing);
      service.flow.observe(
        PurchaseDetails(
          productID: status == PurchaseStatus.pending ? service.product.id : '',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'test',
          ),
          transactionDate: null,
          status: status,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Finalizing Purchase…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Welcome to Premium'), findsNothing);
      expect(find.textContaining('Purchase received'), findsNothing);
      final button = find.ancestor(
        of: subscribe,
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      if (status == PurchaseStatus.canceled) {
        expect(find.text('Purchase canceled.'), findsOneWidget);
        await tester.tap(subscribe);
        await tester.pump();
        expect(find.text('Finalizing Purchase…'), findsOneWidget);
        service.flow.fail();
        await tester.pumpAndSettle();
        expect(service.launches, 2);
      }
    });
  }
  group('annual plan value', () {
    test('calculates savings against twelve monthly payments', () {
      expect(annualSavingsPercent(monthlyPrice: 5, annualPrice: 48), 20);
    });

    test('does not advertise savings when annual costs more', () {
      expect(annualSavingsPercent(monthlyPrice: 5, annualPrice: 65), isNull);
    });
  });
}

class CheckoutTestService implements SubscriptionService {
  CheckoutTestService({this.premium = false});
  final bool premium;
  final flow = StorePurchaseFlow();
  int launches = 0;
  final product = ProductDetails(
    id: 'premium',
    title: 'Premium',
    description: 'Premium',
    price: r'$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );
  @override
  List<ProductDetails> get products => [product];
  @override
  bool get purchasePending => flow.busy;
  @override
  Listenable get purchaseActivity => flow;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isPremiumActive() async => premium;
  @override
  Future<PremiumEntitlement?> getPremiumEntitlement() async => null;
  @override
  List<ProductDetails> get aiPackProducts => [];
  @override
  bool isAnnualProduct(ProductDetails product) => false;
  @override
  bool hasIntroductoryOffer(ProductDetails product) => false;
  @override
  bool hasFreeTrial(ProductDetails product) => false;
  @override
  String? introductoryOfferLabel(ProductDetails product) => null;
  @override
  String subscriptionPeriod(ProductDetails product) => 'month';
  @override
  String recurringPrice(ProductDetails product) => product.price;
  @override
  double recurringRawPrice(ProductDetails product) => product.rawPrice;
  @override
  SubscriptionPlan get premiumPlan => SubscriptionPlan(
    id: product.id,
    title: 'Premium',
    description: 'Premium',
    price: product.price,
    features: ['Premium features'],
  );
  @override
  Future<StorePurchaseResult> purchaseSubscription(ProductDetails product) =>
      flow.run(
        productId: product.id,
        launch: () async {
          launches++;
          return true;
        },
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
