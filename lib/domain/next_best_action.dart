import 'dart:convert';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/domain/recommendation_goal.dart';

String recommendationGameKey(UnifiedGame game) {
  final identities =
      game.platforms
          .map(
            (p) => jsonEncode([
              p.platformId ?? p.platform,
              p.platformGameId ?? p.gameId,
            ]),
          )
          .toList()
        ..sort();
  return jsonEncode(identities.isEmpty ? [game.title] : identities);
}

enum NextBestActionType {
  connectPlatform,
  claimReward,
  protectStreak,
  finishGame,
  previewPremium,
  browse,
}

class NextBestAction {
  const NextBestAction({
    required this.type,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.game,
  });

  final NextBestActionType type;
  final String title;
  final String description;
  final String buttonLabel;
  final UnifiedGame? game;

  String get analyticsId => type.name;
}

NextBestAction chooseNextBestAction({
  required List<UnifiedGame> games,
  required bool isPremium,
  bool allowPremiumPreview = true,
  int availableRewardXp = 0,
  int currentStreak = 0,
  int todayUnlocks = 0,
  DateTime? now,
  Set<String> skippedGameKeys = const {},
  RecommendationGoals goals = const RecommendationGoals(),
}) {
  if (games.isEmpty) {
    return const NextBestAction(
      type: NextBestActionType.connectPlatform,
      title: 'Build your gaming profile',
      description:
          'Connect PlayStation, Xbox, or Steam to calculate your StatusXP.',
      buttonLabel: 'Connect a Platform',
    );
  }

  if (availableRewardXp > 0) {
    return NextBestAction(
      type: NextBestActionType.claimReward,
      title: '$availableRewardXp StatusXP ready to claim',
      description: 'Collect your completed challenge reward now.',
      buttonLabel: 'Claim Reward',
    );
  }

  if (currentStreak >= 2 && todayUnlocks == 0) {
    return NextBestAction(
      type: NextBestActionType.protectStreak,
      title: 'Protect your $currentStreak-day streak',
      description:
          'Make progress on a daily challenge to keep your momentum alive.',
      buttonLabel: 'View Daily Challenges',
    );
  }

  final clock = now ?? DateTime.now();
  UnifiedGame? closestFinish;
  double bestScore = -1;
  int? selectedActivityDays;
  bool selectedPlatinum = false;
  for (final game in games) {
    if (skippedGameKeys.contains(recommendationGameKey(game))) continue;
    final playstation = game.platforms
        .where(
          (p) =>
              [1, 2, 5, 9].contains(p.platformId) ||
              p.platform.toLowerCase().startsWith('ps') ||
              p.platform.toLowerCase() == 'playstation',
        )
        .toList();
    final platinumGoal =
        goals.forGame(recommendationGameKey(game)) ==
            RecommendationGoal.platinum &&
        playstation.isNotEmpty;
    if (platinumGoal && playstation.every((p) => p.hasPlatinum)) continue;
    if (!game.overallCompletion.isFinite ||
        (!platinumGoal && game.overallCompletion < 20) ||
        game.overallCompletion >= 100) {
      continue;
    }
    // Last-played can be a sync timestamp. Only earned achievement dates
    // provide evidence of recent progress; ignore future timestamps.
    DateTime? latestUnlock;
    for (final platform
        in platinumGoal
            ? playstation.where((p) => !p.hasPlatinum)
            : game.platforms) {
      final earned = platform.lastTrophyEarnedAt;
      if (earned != null &&
          !earned.isAfter(clock) &&
          (latestUnlock == null || earned.isAfter(latestUnlock))) {
        latestUnlock = earned;
      }
    }
    final age = latestUnlock == null
        ? null
        : clock.difference(latestUnlock).inDays;
    final bonus = age != null && age < 7
        ? 30
        : age != null && age < 30
        ? 15
        : 0;
    // Overall completion may include DLC. Never use it as platinum proximity.
    final score = platinumGoal ? 50.0 + bonus : game.overallCompletion + bonus;
    if (closestFinish == null ||
        score > bestScore ||
        (score == bestScore && game.title.compareTo(closestFinish.title) < 0)) {
      closestFinish = game;
      bestScore = score;
      selectedActivityDays = age;
      selectedPlatinum = platinumGoal;
    }
  }

  if (closestFinish != null) {
    return NextBestAction(
      type: NextBestActionType.finishGame,
      title: selectedPlatinum
          ? 'Platinum goal: ${closestFinish.title}'
          : 'Continue ${closestFinish.title}',
      description: selectedPlatinum
          ? 'No platinum is recorded on at least one PlayStation version. Review its trophies first: platinum availability and required groups are not verified. Ranked by recent trophy activity, not DLC completion.'
          : '${closestFinish.overallCompletion.toStringAsFixed(0)}% complete. '
                '${selectedActivityDays != null && selectedActivityDays < 7
                    ? 'You earned an achievement here in the last 7 days.'
                    : selectedActivityDays != null && selectedActivityDays < 30
                    ? 'You earned an achievement here in the last 30 days.'
                    : 'One of your closest unfinished games.'}',
      buttonLabel: 'View Achievements',
      game: closestFinish,
    );
  }

  if (skippedGameKeys.isNotEmpty) {
    return const NextBestAction(
      type: NextBestActionType.browse,
      title: 'Explore your next game',
      description:
          'You have seen the current suggestions. Browse games or reset your suggestions to start again.',
      buttonLabel: 'Browse Games',
    );
  }

  if (!isPremium && allowPremiumPreview) {
    return const NextBestAction(
      type: NextBestActionType.previewPremium,
      title: 'Find your fastest next win',
      description:
          'Preview Premium Analytics to uncover progress and achievement opportunities.',
      buttonLabel: 'Preview Insights',
    );
  }

  return const NextBestAction(
    type: NextBestActionType.browse,
    title: 'Choose your next challenge',
    description: 'Discover another game and keep growing your StatusXP.',
    buttonLabel: 'Browse Games',
  );
}
