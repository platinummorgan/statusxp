import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/engagement_repository.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EngagementRepository(client);
});

final engagementSnapshotProvider =
    FutureProvider.autoDispose<EngagementSnapshot>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return repository.getEngagementSnapshot(userId);
    });

final socialTargetsProvider = FutureProvider.autoDispose<List<SocialTarget>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final repository = ref.watch(engagementRepositoryProvider);
  return repository.getSocialTargets(userId);
});

final socialHighlightsProvider =
    FutureProvider.autoDispose<List<SocialHighlight>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return repository.getSocialHighlights(userId);
    });

final playNextRecommendationsProvider =
    FutureProvider.autoDispose<List<PlayNextRecommendation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return repository.getPlayNextRecommendations(userId);
    });
