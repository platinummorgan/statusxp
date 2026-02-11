import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/premium_features_repository.dart';
import 'package:statusxp/domain/premium_features_data.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final premiumFeaturesRepositoryProvider = Provider<PremiumFeaturesRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return PremiumFeaturesRepository(client);
});

final goalsPaceDataProvider = FutureProvider.autoDispose
    .family<GoalsPaceData, GoalsMetric>((ref, metric) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(premiumFeaturesRepositoryProvider);
      return repository.getGoalsPaceData(userId, metric: metric);
    });

final goalsRangeDataProvider = FutureProvider.autoDispose
    .family<PaceWindowInsight, GoalsRangeQuery>((ref, query) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(premiumFeaturesRepositoryProvider);
      return repository.getGoalsRangeData(
        userId,
        metric: query.metric,
        start: query.start,
        end: query.end,
      );
    });

final rivalCompareDataProvider = FutureProvider.autoDispose<RivalCompareData>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final repository = ref.watch(premiumFeaturesRepositoryProvider);
  return repository.getRivalCompareData(userId);
});

final achievementRadarDataProvider =
    FutureProvider.autoDispose<AchievementRadarData>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(premiumFeaturesRepositoryProvider);
      return repository.getAchievementRadarData(userId);
    });
