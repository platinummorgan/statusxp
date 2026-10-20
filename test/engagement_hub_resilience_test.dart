import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/engagement_repository.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/state/engagement_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/engagement_hub_screen.dart';

const player = SocialTarget(
  userId: 'other',
  displayName: 'Visible player',
  avatarUrl: null,
  totalStatusXp: 42,
  weeklyGain: 2,
  monthlyGain: 4,
  isFollowing: false,
  isRivalWatchlisted: false,
);
const timeout = PostgrestException(
  message: 'canceling statement due to statement timeout',
  code: '57014',
);

class TestRepository extends EngagementRepository {
  TestRepository(this.load) : super(Supabase.instance.client);
  final Future<List<SocialTarget>> Function(String, int) load;
  int reads = 0;
  @override
  Future<List<SocialTarget>> getSocialTargets(
    String userId, {
    int limit = 30,
  }) => load(userId, ++reads);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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

  ProviderContainer containerFor(TestRepository repository) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('owner'),
        engagementRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final listener = container.listen(socialTargetsProvider, (_, _) {});
    addTearDown(listener.close);
    return container;
  }

  testWidgets(
    'a timeout retries automatically without navigating or refreshing',
    (tester) async {
      final repo = TestRepository((_, attempt) async {
        if (attempt == 1) throw timeout;
        return [player];
      });
      final container = containerFor(repo);
      await expectLater(
        container.read(socialTargetsProvider.future),
        throwsA(isA<PostgrestException>()),
      );
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(await container.read(socialTargetsProvider.future), [player]);
      expect(repo.reads, 2);
    },
  );

  testWidgets(
    'same-account saved section survives a failed refresh then updates automatically',
    (tester) async {
      final repo = TestRepository((_, attempt) async {
        if (attempt == 2) throw timeout;
        return attempt == 1 ? [player] : [];
      });
      final container = containerFor(repo);
      expect(await container.read(socialTargetsProvider.future), [player]);
      container.invalidate(socialTargetsProvider);
      expect(await container.read(socialTargetsProvider.future), [player]);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(await container.read(socialTargetsProvider.future), isEmpty);
      expect(repo.reads, 3);
    },
  );

  testWidgets('saved sections are cleared when accounts change', (
    tester,
  ) async {
    final repo = TestRepository((user, attempt) async {
      if (user != 'owner' && attempt == 2) throw timeout;
      return user == 'owner' ? [player] : [];
    });
    final container = containerFor(repo);
    expect(await container.read(socialTargetsProvider.future), [player]);
    container.updateOverrides([
      currentUserIdProvider.overrideWithValue('second'),
      engagementRepositoryProvider.overrideWithValue(repo),
    ]);
    await expectLater(
      container.read(socialTargetsProvider.future),
      throwsA(isA<PostgrestException>()),
    );
    expect(
      container
          .read(socialTargetsProvider)
          .when(
            skipLoadingOnReload: false,
            data: (value) => value,
            error: (_, _) => null,
            loading: () => null,
          ),
      isNull,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(await container.read(socialTargetsProvider.future), isEmpty);
  });

  testWidgets(
    'permission errors are neither retried nor presented as cached successes',
    (tester) async {
      final repo = TestRepository((_, attempt) async {
        if (attempt > 1) {
          throw const PostgrestException(
            message: 'Access denied',
            code: '42501',
          );
        }
        return [player];
      });
      final container = containerFor(repo);
      await container.read(socialTargetsProvider.future);
      container.invalidate(socialTargetsProvider);
      await expectLater(
        container.read(socialTargetsProvider.future),
        throwsA(isA<PostgrestException>()),
      );
      await tester.pump(const Duration(seconds: 20));
      expect(repo.reads, 2);
      expect(container.read(socialTargetsProvider).hasError, isTrue);
    },
  );

  testWidgets(
    'one failed and one slow request leave successful sections visible without raw errors',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialTargetsProvider.overrideWith((ref) async => [player]),
            socialHighlightsProvider.overrideWith(
              (ref) => Completer<List<SocialHighlight>>().future,
            ),
            engagementSnapshotProvider.overrideWith(
              (ref) async => throw timeout,
            ),
            playNextRecommendationsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: EngagementHubScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Visible player'), findsOneWidget);
      expect(
        find.text('This section is unavailable right now.'),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('statement timeout'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
