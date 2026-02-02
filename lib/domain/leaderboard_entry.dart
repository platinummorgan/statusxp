/// Leaderboard entry model
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final int gamesCount;
  final int? previousRank;
  final int rankChange;
  final bool isNew;
  
  // PSN Trophy Breakdown
  final int? platinumCount;
  final int? goldCount;
  final int? silverCount;
  final int? bronzeCount;
  final int? totalTrophies;
  
  // Potential Stats
  final int? potentialScore;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.score,
    required this.gamesCount,
    this.previousRank,
    this.rankChange = 0,
    this.isNew = false,
    this.platinumCount,
    this.goldCount,
    this.silverCount,
    this.bronzeCount,
    this.totalTrophies,
    this.potentialScore,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      gamesCount: (json['games_count'] as num?)?.toInt() ?? 0,
      previousRank: json['previous_rank'] as int?,
      rankChange: (json['rank_change'] as int?) ?? 0,
      isNew: (json['is_new'] as bool?) ?? false,
      platinumCount: (json['platinum_count'] as num?)?.toInt(),
      goldCount: (json['gold_count'] as num?)?.toInt(),
      silverCount: (json['silver_count'] as num?)?.toInt(),
      bronzeCount: (json['bronze_count'] as num?)?.toInt(),
      totalTrophies: (json['total_trophies'] as num?)?.toInt(),
      potentialScore: (json['potential_score'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'score': score,
      'games_count': gamesCount,
      'previous_rank': previousRank,
      'rank_change': rankChange,
      'is_new': isNew,
      'platinum_count': platinumCount,
      'gold_count': goldCount,
      'silver_count': silverCount,
      'bronze_count': bronzeCount,
      'total_trophies': totalTrophies,
      'potential_score': potentialScore,
    };
  }
}
