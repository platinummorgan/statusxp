enum RecommendationGoal { completion, platinum }

class RecommendationGoals {
  const RecommendationGoals({
    this.defaultGoal = RecommendationGoal.completion,
    this.games = const {},
  });
  final RecommendationGoal defaultGoal;
  final Map<String, RecommendationGoal> games;
  RecommendationGoal forGame(String key) => games[key] ?? defaultGoal;
  Map<String, dynamic> toJson() => {
    'default': defaultGoal.name,
    'games': games.map((key, value) => MapEntry(key, value.name)),
  };
  factory RecommendationGoals.fromJson(Map<String, dynamic> json) =>
      RecommendationGoals(
        defaultGoal: json['default'] == 'platinum'
            ? RecommendationGoal.platinum
            : RecommendationGoal.completion,
        games: {
          for (final entry in (json['games'] as Map? ?? {}).entries)
            if (entry.key is String &&
                ['completion', 'platinum'].contains(entry.value))
              entry.key as String: entry.value == 'platinum'
                  ? RecommendationGoal.platinum
                  : RecommendationGoal.completion,
        },
      );
}
