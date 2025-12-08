/// Leaderboard entry model
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final int gamesCount;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.score,
    required this.gamesCount,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      gamesCount: (json['games_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'score': score,
      'games_count': gamesCount,
    };
  }
}
