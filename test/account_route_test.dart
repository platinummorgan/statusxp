import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/auth/auth_gate.dart';
import 'package:statusxp/utils/html.dart' as html;
import 'account_state_test.dart' show TestAuth, event, user;

class AccountProbe extends StatefulWidget {
  const AccountProbe({super.key});
  @override
  State<AccountProbe> createState() => _AccountProbeState();
}

class _AccountProbeState extends State<AccountProbe> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('Local count: $count'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (kIsWeb) html.document.cookie = 'onboarding_complete=true; path=/';
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await Supabase.initialize(
      url: 'https://test.invalid',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('web guest route observes login without being recreated', (
    tester,
  ) async {
    final auth = TestAuth();
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          home: AuthGate(location: '/games/browse', child: AccountProbe()),
        ),
      ),
    );
    auth.events.add(event(null, AuthChangeEvent.initialSession));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    await tester.tap(find.text('Local count: 0'));
    await tester.pump();
    auth.events.add(event('A'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Local count: 0'), findsOneWidget);
    auth.events.add(event(null, AuthChangeEvent.signedOut));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Local count: 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !kIsWeb);

  testWidgets(
    'account change resets local screen state but token refresh preserves it',
    (tester) async {
      final auth = TestAuth()..currentUser = user('A');
      addTearDown(auth.events.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(auth)],
          child: const MaterialApp(
            home: AuthGate(location: '/games/browse', child: AccountProbe()),
          ),
        ),
      );
      auth.events.add(event('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local count: 0'));
      await tester.pump();
      auth.events.add(event('A', AuthChangeEvent.tokenRefreshed));
      await tester.pumpAndSettle();
      expect(find.text('Local count: 1'), findsOneWidget);
      auth.events.add(event('B'));
      await tester.pumpAndSettle();
      expect(find.text('Local count: 0'), findsOneWidget);
      expect(find.text('Local count: 1'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
