import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/security_reconnect_provider.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/auth/security_reconnect_gate.dart';

class FakeReconnectRepository implements SecurityReconnectRepository {
  List<SecurityReconnectRequirement> pending = [];
  bool failLoad = false;
  bool failVerify = false;
  int loads = 0;
  int verifications = 0;
  Completer<List<SecurityReconnectRequirement>>? delayedLoad;

  @override
  Future<List<SecurityReconnectRequirement>> load() async {
    loads++;
    if (failLoad) throw StateError('Offline');
    if (delayedLoad != null) return delayedLoad!.future;
    return List.of(pending);
  }

  @override
  Future<void> reportReset(String platform) async {
    pending = pending
        .map(
          (r) => SecurityReconnectRequirement(
            platform: r.platform,
            accountId: r.accountId,
            resetReported: r.platform == platform || r.resetReported,
            syncActive: r.syncActive,
          ),
        )
        .toList();
  }

  @override
  Future<void> verifySteam() async {
    verifications++;
    if (failVerify) throw StateError('Invalid key');
    pending.removeWhere((r) => r.platform == 'steam');
  }

  @override
  Future<void> stopSync(String platform) async {
    pending = pending
        .map(
          (r) => SecurityReconnectRequirement(
            platform: r.platform,
            accountId: r.accountId,
            resetReported: r.resetReported,
            syncActive: false,
          ),
        )
        .toList();
  }
}

const steam = SecurityReconnectRequirement(
  platform: 'steam',
  accountId: '76561198999999991',
  resetReported: false,
  syncActive: false,
);
const psn = SecurityReconnectRequirement(
  platform: 'psn',
  accountId: '12345',
  resetReported: true,
  syncActive: false,
);
const readySteam = SecurityReconnectRequirement(
  platform: 'steam',
  accountId: '76561198999999991',
  resetReported: true,
  syncActive: false,
);
Future<void> render(
  WidgetTester tester,
  FakeReconnectRepository repo, {
  Future<bool?> Function(SecurityReconnectRequirement)? onConnect,
  String? platform = 'steam',
  VoidCallback? onContinue,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        securityReconnectRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: SecurityReconnectGate(
          onConnect: onConnect,
          platform: platform,
          onContinue: onContinue,
          child: const Scaffold(body: Text('Protected dashboard')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'app remains accessible during pending and failed reconnect checks',
    (tester) async {
      final repo = FakeReconnectRepository()..delayedLoad = Completer();
      await render(tester, repo, platform: null);
      await tester.pump();
      expect(find.text('Protected dashboard'), findsOneWidget);
      repo.delayedLoad!.complete([psn, readySteam]);
      await tester.pumpAndSettle();
      expect(find.text('Protected dashboard'), findsOneWidget);
      expect(find.text('Reconnect PlayStation'), findsNothing);
      repo.delayedLoad = null;
      repo.failLoad = true;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SecurityReconnectGate)),
      );
      container.invalidate(securityReconnectRequirementsProvider);
      await tester.pumpAndSettle();
      expect(find.text('Protected dashboard'), findsOneWidget);
    },
  );

  testWidgets('PS-only reconnect leaves Steam sync available', (tester) async {
    final repo = FakeReconnectRepository()..pending = [psn];
    await render(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
    expect(find.text('Reconnect PlayStation'), findsNothing);
    expect(repo.pending, [psn]);
  });

  testWidgets(
    'sync reconnect lists only the selected platform and can return to dashboard',
    (tester) async {
      final repo = FakeReconnectRepository()..pending = [psn, readySteam];
      final router = GoRouter(
        initialLocation: '/sync',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Saved games')),
          ),
          GoRoute(
            path: '/sync',
            builder: (_, _) => const SecurityReconnectGate(
              platform: 'psn',
              child: Scaffold(body: Text('Sync controls')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            securityReconnectRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reconnect PlayStation'), findsOneWidget);
      expect(find.text('Reconnect Steam'), findsNothing);
      expect(find.text('Sync controls'), findsNothing);
      await tester.tap(find.text('Back to dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Saved games'), findsOneWidget);
      expect(repo.pending.length, 2);
    },
  );

  testWidgets('sync connection check failure still allows leaving', (
    tester,
  ) async {
    var left = false;
    final repo = FakeReconnectRepository()..failLoad = true;
    await render(tester, repo, onContinue: () => left = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to dashboard'));
    expect(left, isTrue);
    expect(find.text('Protected dashboard'), findsNothing);
  });

  testWidgets('switching signed-in users discards cached unlocked state', (
    tester,
  ) async {
    final owner = StateProvider<String>((ref) => 'first');
    final first = FakeReconnectRepository();
    final second = FakeReconnectRepository()..pending = [readySteam];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(owner)),
          securityReconnectRepositoryProvider.overrideWith(
            (ref) => ref.watch(owner) == 'first' ? first : second,
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return SecurityReconnectGate(
                key: ValueKey(ref.watch(owner)),
                platform: 'steam',
                child: const Scaffold(body: Text('Protected dashboard')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
    final context = tester.element(find.byType(SecurityReconnectGate));
    ProviderScope.containerOf(context).read(owner.notifier).state = 'second';
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsNothing);
    expect(find.text('Reconnect Steam'), findsOneWidget);
  });

  testWidgets('loading and network failure never expose sync controls', (
    tester,
  ) async {
    final repo = FakeReconnectRepository()..delayedLoad = Completer();
    await render(tester, repo);
    await tester.pump();
    await tester.pump();
    expect(repo.loads, 1);
    expect(find.text('Protected dashboard'), findsNothing);
    repo.delayedLoad!.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('users without a requirement continue normally', (tester) async {
    await render(tester, FakeReconnectRepository());
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
  });

  testWidgets('failed connection checks recover automatically', (tester) async {
    final repo = FakeReconnectRepository()..failLoad = true;
    await render(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsNothing);
    expect(repo.loads, 1);
    repo.failLoad = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(find.text('Protected dashboard'), findsOneWidget);
  });

  testWidgets('confirmation enables reconnect but does not enable sync', (
    tester,
  ) async {
    final repo = FakeReconnectRepository()..pending = [steam];
    await render(tester, repo, onConnect: (_) async => false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reconnect Steam'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('I completed the security steps'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsNothing);
    await tester.tap(find.text('Reconnect Steam'));
    await tester.pumpAndSettle();
    expect(repo.verifications, 0);
    expect(find.text('Protected dashboard'), findsNothing);
  });

  testWidgets(
    'invalid replacement stays locked; verified replacement unlocks',
    (tester) async {
      final repo = FakeReconnectRepository()
        ..pending = [readySteam]
        ..failVerify = true;
      await render(tester, repo, onConnect: (_) async => true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconnect Steam'));
      await tester.pumpAndSettle();
      expect(repo.verifications, 1);
      expect(find.text('Protected dashboard'), findsNothing);
      expect(
        find.textContaining('Reconnect could not be verified'),
        findsOneWidget,
      );
      repo.failVerify = false;
      await tester.tap(find.text('Reconnect Steam'));
      await tester.pumpAndSettle();
      expect(repo.verifications, 2);
      expect(find.text('Protected dashboard'), findsOneWidget);
    },
  );

  testWidgets('another pending platform does not block a verified sync', (
    tester,
  ) async {
    final repo = FakeReconnectRepository()..pending = [psn, readySteam];
    await render(tester, repo, onConnect: (_) async => true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconnect Steam'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
    expect(find.text('Reconnect PlayStation'), findsNothing);
  });

  testWidgets('active sync must stop before reconnecting', (tester) async {
    final repo = FakeReconnectRepository()
      ..pending = [
        const SecurityReconnectRequirement(
          platform: 'steam',
          accountId: '76561198999999991',
          resetReported: true,
          syncActive: true,
        ),
      ];
    await render(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Reconnect Steam'), findsNothing);
    await tester.tap(find.text('Stop sync'));
    await tester.pumpAndSettle();
    expect(find.text('Reconnect Steam'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
  });

  testWidgets('rechecking keeps the verified screen until a failure', (
    tester,
  ) async {
    final repo = FakeReconnectRepository();
    await render(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
    repo.delayedLoad = Completer<List<SecurityReconnectRequirement>>();
    final element = tester.element(find.byType(SecurityReconnectGate));
    ProviderScope.containerOf(
      element,
    ).invalidate(securityReconnectRequirementsProvider);
    await tester.pump();
    await tester.pump();
    expect(repo.loads, 2);
    expect(find.text('Protected dashboard'), findsOneWidget);
    repo.delayedLoad!.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsNothing);
  });
}
