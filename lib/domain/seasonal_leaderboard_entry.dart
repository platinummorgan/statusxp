enum SeasonalBoardType {
  statusXP,
  platinums,
  xbox,
  steam,
}

enum LeaderboardPeriodType {
  weekly,
  monthly,
}

class SeasonalLeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int periodGain;
  final int currentScore;
  final int baselineScore;
  final int gamesCount;
  final int? potentialScore;
  final int? platinumCount;
  final int? goldCount;
  final int? silverCount;
  final int? bronzeCount;
  final int? totalTrophies;

  const SeasonalLeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.periodGain,
    required this.currentScore,
    required this.baselineScore,
    required this.gamesCount,
    this.potentialScore,
    this.platinumCount,
    this.goldCount,
    this.silverCount,
    this.bronzeCount,
    this.totalTrophies,
  });
}

class SeasonalLeaderboardQuery {
  final SeasonalBoardType boardType;
  final LeaderboardPeriodType periodType;
  final int limit;
  final int offset;

  const SeasonalLeaderboardQuery({
    required this.boardType,
    required this.periodType,
    this.limit = 100,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeasonalLeaderboardQuery &&
        other.boardType == boardType &&
        other.periodType == periodType &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(boardType, periodType, limit, offset);
}
