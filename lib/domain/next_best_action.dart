import 'package:statusxp/domain/unified_game.dart';

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
  int availableRewardXp = 0,
  int currentStreak = 0,
  int todayUnlocks = 0,
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

  UnifiedGame? closestFinish;
  for (final game in games) {
    if (game.overallCompletion < 20 || game.overallCompletion >= 100) continue;
    if (closestFinish == null ||
        game.overallCompletion > closestFinish.overallCompletion) {
      closestFinish = game;
    }
  }

  if (closestFinish != null) {
    return NextBestAction(
      type: NextBestActionType.finishGame,
      title: 'Finish ${closestFinish.title}',
      description:
          'You are ${closestFinish.overallCompletion.toStringAsFixed(0)}% complete. Keep the momentum going.',
      buttonLabel: 'View Achievements',
      game: closestFinish,
    );
  }

  if (!isPremium) {
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
