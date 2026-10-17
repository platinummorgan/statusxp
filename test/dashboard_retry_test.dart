import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/dashboard_cache.dart';
import 'package:statusxp/data/repositories/supabase_dashboard_repository.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'helpers/test_helpers.dart';

class RecoveringDashboardRepository extends SupabaseDashboardRepository {
  RecoveringDashboardRepository() : super(Supabase.instance.client);
  int reads = 0;

  @override
  Future<DashboardStats> getDashboardStats(String userId) async {
    reads++;
    if (reads == 1) throw StateError('SocketException: offline');
    return sampleDashboardStats;
  }
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

  testWidgets(
    'failed dashboard requests retry and save fresh stats automatically',
    (tester) async {
      final repository = RecoveringDashboardRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('owner'),
          dashboardRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(dashboardStatsProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(dashboardStatsProvider.future), isNull);
      expect(repository.reads, 1);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
      expect(
        container.read(dashboardStatsProvider).valueOrNull,
        sampleDashboardStats,
      );
      expect(await DashboardCache().read('owner'), sampleDashboardStats);
      expect(await DashboardCache().read('another-account'), isNull);
    },
  );
}
