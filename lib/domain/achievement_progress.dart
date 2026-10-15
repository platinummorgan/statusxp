bool hasKnownAchievementTotal(int earned, int total) =>
    total > 0 && total >= earned;

String achievementCountLabel(int earned, int total) =>
    '$earned/${hasKnownAchievementTotal(earned, total) ? total : '?'}';

String achievementCompletionLabel(int earned, int total, double percentage) =>
    hasKnownAchievementTotal(earned, total)
    ? '${percentage.clamp(0, 100).toStringAsFixed(0)}%'
    : 'Unknown';
