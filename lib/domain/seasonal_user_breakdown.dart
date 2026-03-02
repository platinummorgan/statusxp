import 'package:equatable/equatable.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';

class SeasonalUserBreakdownQuery extends Equatable {
  final String targetUserId;
  final SeasonalBoardType boardType;
  final LeaderboardPeriodType periodType;
  final int limit;
  final int offset;

  const SeasonalUserBreakdownQuery({
    required this.targetUserId,
    required this.boardType,
    required this.periodType,
    this.limit = 200,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [
    targetUserId,
    boardType,
    periodType,
    limit,
    offset,
  ];
}

class SeasonalGameContribution extends Equatable {
  final int platformId;
  final String platformGameId;
  final String gameName;
  final String? coverUrl;
  final int periodGain;
  final int earnedCount;

  const SeasonalGameContribution({
    required this.platformId,
    required this.platformGameId,
    required this.gameName,
    required this.coverUrl,
    required this.periodGain,
    required this.earnedCount,
  });

  @override
  List<Object?> get props => [
    platformId,
    platformGameId,
    gameName,
    coverUrl,
    periodGain,
    earnedCount,
  ];
}

class SeasonalUserBreakdownData extends Equatable {
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<SeasonalGameContribution> contributions;

  const SeasonalUserBreakdownData({
    required this.periodStart,
    required this.periodEnd,
    required this.contributions,
  });

  int get totalGain =>
      contributions.fold<int>(0, (sum, row) => sum + row.periodGain);

  @override
  List<Object?> get props => [periodStart, periodEnd, contributions];
}
