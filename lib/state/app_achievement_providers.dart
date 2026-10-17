import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/meta_achievement_repository.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
import 'package:statusxp/services/achievement_checker_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final achievementCheckerServiceProvider = Provider<AchievementCheckerService>(
  (ref) => AchievementCheckerService(ref.watch(supabaseClientProvider)),
);

/// Also observes awards made while Steam/background syncs finish on the server.
final appAchievementUpdatesProvider = StreamProvider.autoDispose<String>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value('');
  return ref
      .watch(supabaseClientProvider)
      .from('user_meta_achievements')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
        final values =
            rows
                .map(
                  (row) =>
                      '${row['achievement_id']}:${row['unlocked_at']}:${row['custom_title']}',
                )
                .toList()
              ..sort();
        return values.join('|');
      })
      .distinct();
});

final allAchievementsProvider = FutureProvider.autoDispose
    .family<List<MetaAchievement>, String>((ref, userId) async {
      if (userId.isEmpty || userId != ref.watch(currentUserIdProvider)) {
        return [];
      }
      final repository = ref.watch(metaAchievementRepositoryProvider);
      final platformsFuture = ref.watch(connectedPlatformsProvider.future);
      var disposed = false;
      Timer? retry;
      ref.onDispose(() {
        disposed = true;
        retry?.cancel();
      });
      try {
        final platforms = await platformsFuture;
        if (disposed) return [];
        return await repository.getAllAchievements(
          userId,
          connectedPlatforms: platforms,
        );
      } catch (_) {
        if (!disposed) {
          retry = Timer(const Duration(seconds: 10), ref.invalidateSelf);
        }
        rethrow;
      }
    });
