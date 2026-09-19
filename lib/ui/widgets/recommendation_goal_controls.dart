import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/domain/recommendation_goal.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/recommendation_preferences.dart';

class RecommendationGoalControls extends ConsumerWidget {
  const RecommendationGoalControls({
    super.key,
    required this.userId,
    required this.games,
    this.selectedGame,
  });
  final String userId;
  final List<UnifiedGame> games;
  final UnifiedGame? selectedGame;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(recommendationGoalsProvider(userId));
    return TextButton.icon(
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Recommendation goals'),
      onPressed: value.isLoading
          ? null
          : () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _GoalDialog(
                userId: userId,
                initial: value.asData?.value ?? const RecommendationGoals(),
                games: games,
                selectedGame: selectedGame,
              ),
            ),
    );
  }
}

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({
    required this.userId,
    required this.initial,
    required this.games,
    this.selectedGame,
  });
  final String userId;
  final RecommendationGoals initial;
  final List<UnifiedGame> games;
  final UnifiedGame? selectedGame;
  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late RecommendationGoal _default = widget.initial.defaultGoal;
  late final _overrides = Map<String, RecommendationGoal>.of(
    widget.initial.games,
  );
  late String? _game = widget.selectedGame == null
      ? null
      : recommendationGameKey(widget.selectedGame!);
  bool _saving = false;
  bool _failed = false;
  @override
  Widget build(BuildContext context) {
    final games = {
      for (final game in widget.games) recommendationGameKey(game): game,
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Recommendation goals'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your default, then override individual games. Saved for your account on this device.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RecommendationGoal>(
                  initialValue: _default,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Default goal'),
                  items: const [
                    DropdownMenuItem(
                      value: RecommendationGoal.completion,
                      child: Text('100% including DLC'),
                    ),
                    DropdownMenuItem(
                      value: RecommendationGoal.platinum,
                      child: Text('Platinum (PlayStation)'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (goal) => setState(() => _default = goal!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: games.containsKey(_game) ? _game : '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Override a game',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    ...games.entries.map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (game) =>
                            setState(() => _game = game == '' ? null : game),
                ),
                if (_game != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_game),
                    initialValue: _overrides[_game]?.name ?? 'default',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'This game’s goal',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'default',
                        child: Text('Use account default'),
                      ),
                      DropdownMenuItem(
                        value: 'completion',
                        child: Text('100% including DLC'),
                      ),
                      DropdownMenuItem(
                        value: 'platinum',
                        child: Text('Platinum (PlayStation)'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (goal) => setState(() {
                            if (goal == 'default') {
                              _overrides.remove(_game);
                            } else {
                              _overrides[_game!] = goal == 'platinum'
                                  ? RecommendationGoal.platinum
                                  : RecommendationGoal.completion;
                            }
                          }),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Xbox and Steam use achievement completion. Platinum mode skips earned platinums and uses recent trophy activity. Availability and required trophy groups are not yet verified; overall DLC completion is not platinum progress.',
                ),
                if (_failed)
                  const Text(
                    'Could not save. Your choices are kept here; retry.',
                    style: TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() {
                      _saving = true;
                      _failed = false;
                    });
                    try {
                      await ref
                          .read(
                            recommendationGoalsProvider(widget.userId).notifier,
                          )
                          .save(
                            RecommendationGoals(
                              defaultGoal: _default,
                              games: Map.of(_overrides),
                            ),
                          );
                      if (!mounted || !context.mounted) return;
                      ref
                              .read(
                                skippedRecommendationGamesProvider(
                                  widget.userId,
                                ).notifier,
                              )
                              .state =
                          <String>{};
                      Navigator.pop(context);
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          _saving = false;
                          _failed = true;
                        });
                      }
                    }
                  },
            child: Text(_saving ? 'Saving…' : 'Save goals'),
          ),
        ],
      ),
    );
  }
}
