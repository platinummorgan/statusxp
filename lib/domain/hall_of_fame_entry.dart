import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';

class HallOfFameEntry {
  final SeasonalBoardType boardType;
  final LeaderboardPeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String winnerUserId;
  final String winnerDisplayName;
  final String? winnerAvatarUrl;
  final int winnerGain;
  final int winnerCurrentScore;

  const HallOfFameEntry({
    required this.boardType,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.winnerUserId,
    required this.winnerDisplayName,
    this.winnerAvatarUrl,
    required this.winnerGain,
    required this.winnerCurrentScore,
  });
}
