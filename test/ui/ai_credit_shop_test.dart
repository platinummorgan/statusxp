import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:statusxp/services/store_purchase_attempt.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/ui/screens/ai_credit_shop_screen.dart';

class PackTestStore implements SubscriptionService {
  final activity = ChangeNotifier();
  Completer<StorePurchaseResult>? checkout;
  int launches = 0;
  final product = ProductDetails(
    id: SubscriptionService.aiPackSmallId,
    title: 'Small pack',
    description: '20 credits',
    price: '€2.49',
    rawPrice: 2.49,
    currencyCode: 'EUR',
  );
  @override
  List<ProductDetails> get aiPackProducts => [product];
  @override
  Listenable get purchaseActivity => activity;
  @override
  bool get purchasePending => checkout != null && !checkout!.isCompleted;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isPremiumActive() async => true;
  @override
  Future<StorePurchaseResult> purchaseAIPack(ProductDetails selected) {
    expect(selected.id, product.id);
    launches++;
    checkout = Completer<StorePurchaseResult>();
    return checkout!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Premium can buy at store price; credits refresh only after verification',
    (tester) async {
      final store = PackTestStore();
      var balance = 10;
      await tester.pumpWidget(
        MaterialApp(
          home: AICreditShopScreen(
            subscriptionService: store,
            loadBalance: () async => balance,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 pack credits available'), findsOneWidget);
      expect(find.text('Buy for €2.49'), findsOneWidget);
      final buy = find.byKey(const ValueKey('buy-small'));
      await tester.tap(buy);
      await tester.pump();
      await tester.tap(buy);
      expect(store.launches, 1);
      expect(find.text('20 AI credits added!'), findsNothing);
      expect(find.text('10 pack credits available'), findsOneWidget);
      balance = 30;
      store.checkout!.complete(StorePurchaseResult.verified);
      await tester.pumpAndSettle();
      expect(find.text('20 AI credits added!'), findsOneWidget);
      expect(find.text('30 pack credits available'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  for (final result in [
    StorePurchaseResult.canceled,
    StorePurchaseResult.pending,
    StorePurchaseResult.failed,
    StorePurchaseResult.unconfirmed,
  ]) {
    testWidgets('$result does not grant credits and clears local loading', (
      tester,
    ) async {
      final store = PackTestStore();
      await tester.pumpWidget(
        MaterialApp(
          home: AICreditShopScreen(
            subscriptionService: store,
            loadBalance: () async => 10,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buy = find.byKey(const ValueKey('buy-small'));
      await tester.tap(buy);
      await tester.pump();
      store.checkout!.complete(result);
      await tester.pumpAndSettle();
      expect(find.text('20 AI credits added!'), findsNothing);
      expect(find.text('10 pack credits available'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
      if (result == StorePurchaseResult.canceled) {
        expect(find.text('Purchase canceled.'), findsOneWidget);
        await tester.tap(buy);
        await tester.pump();
        expect(store.launches, 2);
        store.checkout!.complete(StorePurchaseResult.canceled);
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'unavailable packs stay disabled and failed balance reads are not zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AICreditShopScreen(
            subscriptionService: PackTestStore(),
            loadBalance: () async => throw StateError('offline'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Credit balance unavailable'), findsOneWidget);
      expect(find.text('0 pack credits available'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-medium')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('shop scrolls above phone navigation inset with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: 48),
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: AICreditShopScreen(
          subscriptionService: PackTestStore(),
          loadBalance: () async => 10,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('buy-large'));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(last).dy, lessThanOrEqualTo(592));
    expect(tester.takeException(), isNull);
  });
}
