import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/domain/seasonal_user_breakdown.dart';
import 'package:statusxp/domain/weekly_recap.dart';
import 'package:statusxp/state/engagement_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final weeklyRecapProvider = FutureProvider.autoDispose<WeeklyRecap>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');

  final breakdown = await ref.watch(
    seasonalUserBreakdownProvider(
      SeasonalUserBreakdownQuery(
        targetUserId: userId,
        boardType: SeasonalBoardType.statusXP,
        periodType: LeaderboardPeriodType.weekly,
      ),
    ).future,
  );
  final engagementFuture = ref.watch(engagementSnapshotProvider.future);
  final trophyRoomFuture = ref.watch(trophyRoomDataProvider.future);
  final recommendationsFuture = ref.watch(
    playNextRecommendationsProvider.future,
  );

  return buildWeeklyRecap(
    breakdown: breakdown,
    engagement: await engagementFuture,
    trophyRoom: await trophyRoomFuture,
    recommendations: await recommendationsFuture,
  );
});
