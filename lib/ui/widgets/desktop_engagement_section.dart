import 'package:flutter/material.dart';
import 'package:statusxp/domain/recommendation_goal.dart';
import 'package:statusxp/ui/widgets/recommendation_goal_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/engagement_providers.dart';
import 'package:statusxp/state/recommendation_preferences.dart';
import 'package:statusxp/ui/widgets/daily_momentum_card.dart';
import 'package:statusxp/ui/widgets/next_best_action_card.dart';
import 'package:statusxp/ui/widgets/weekly_recap_card.dart';

class DesktopEngagementSection extends ConsumerStatefulWidget {
  const DesktopEngagementSection({
    super.key,
    required this.userId,
    required this.games,
  });
  final String userId;
  final AsyncValue<List<UnifiedGame>> games;
  @override
  ConsumerState<DesktopEngagementSection> createState() =>
      _DesktopEngagementSectionState();
}

class _DesktopEngagementSectionState
    extends ConsumerState<DesktopEngagementSection> {
  bool _loaded = false;
  String? _hiddenDay;
  String? _hiddenWeek;
  String _day(DateTime date) => '${date.year}-${date.month}-${date.day}';
  String get _today => _day(DateTime.now());
  String get _week {
    final now = DateTime.now();
    return _day(DateTime(now.year, now.month, now.day - now.weekday + 1));
  }

  String _key(String kind) => 'desktop_engagement_${widget.userId}_$kind';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _hiddenDay = prefs.getString(_key('day'));
        _hiddenWeek = prefs.getString(_key('week'));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _dismiss(bool recap) async {
    final value = recap ? _week : _today;
    final key = _key(recap ? 'week' : 'day');
    setState(() {
      if (recap) {
        _hiddenWeek = value;
      } else {
        _hiddenDay = value;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      /* Session dismissal still applies. */
    }
  }

  Future<void> _open(NextBestAction action) async {
    if (action.type == NextBestActionType.finishGame) {
      final platforms = action.game!.platforms;
      PlatformGameData? platform;
      if (platforms.length == 1) {
        platform = platforms.first;
      } else {
        platform = await showDialog<PlatformGameData>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Choose platform'),
            children: platforms
                .map(
                  (p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, p),
                    child: Text(p.platform.toUpperCase()),
                  ),
                )
                .toList(),
          ),
        );
      }
      if (!mounted || platform == null) return;
      final id = platform.platformGameId ?? platform.gameId;
      final game = platform.platformId == null
          ? null
          : GameRef(platformId: platform.platformId!, platformGameId: id);
      if (game == null || game.platform == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game details are not available yet.')),
        );
        return;
      }
      await context.push(game.location);
    } else {
      await context.push(switch (action.type) {
        NextBestActionType.connectPlatform => '/get-started',
        NextBestActionType.claimReward ||
        NextBestActionType.protectStreak => '/engagement-hub',
        NextBestActionType.previewPremium => '/analytics',
        _ => '/games/browse',
      });
    }
    if (mounted) ref.invalidate(engagementSnapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(engagementSnapshotProvider);
    final skippedProvider = skippedRecommendationGamesProvider(widget.userId);
    final skipped = ref.watch(skippedProvider);
    final goals = ref.watch(recommendationGoalsProvider(widget.userId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Your next session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () async {
                await context.push('/engagement-hub');
                if (mounted) ref.invalidate(engagementSnapshotProvider);
              },
              child: const Text('All challenges'),
            ),
            TextButton(
              onPressed: () => context.push('/weekly-recap'),
              child: const Text('Weekly recap'),
            ),
            RecommendationGoalControls(
              userId: widget.userId,
              games: widget.games.asData?.value ?? const [],
            ),
            if (_loaded && _hiddenDay == _today)
              TextButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Show recommendations'),
                onPressed: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    if (!await prefs.remove(_key('day'))) {
                      throw StateError('Save failed');
                    }
                    if (mounted) setState(() => _hiddenDay = null);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not restore recommendations. Please retry.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
        snapshot.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Row(
            children: [
              const Expanded(
                child: Text('Your challenges could not be loaded.'),
              ),
              TextButton(
                onPressed: () => ref.invalidate(engagementSnapshotProvider),
                child: const Text('Retry challenges'),
              ),
            ],
          ),
          data: (value) {
            final games = widget.games.isLoading || widget.games.hasError
                ? null
                : widget.games.asData?.value;
            final action = games == null
                ? null
                : chooseNextBestAction(
                    games: games,
                    skippedGameKeys: skipped,
                    goals: goals.asData?.value ?? const RecommendationGoals(),
                    isPremium: false,
                    allowPremiumPreview: false,
                    availableRewardXp: value.availableRewardXp,
                    currentStreak: value.currentStreak,
                    todayUnlocks: value.todayUnlocks,
                  );
            final cards = <Widget>[
              if (_loaded && _hiddenDay != _today && action != null)
                NextBestActionCard(
                  action: action,
                  onAnother: action.game == null
                      ? null
                      : () {
                          ref.read(skippedProvider.notifier).state = {
                            ...skipped,
                            recommendationGameKey(action.game!),
                          };
                        },
                  onReset: skipped.isEmpty
                      ? null
                      : () {
                          ref.read(skippedProvider.notifier).state = <String>{};
                        },
                  onDismiss: () => _dismiss(false),
                  onTap: () => _open(action),
                ),
              Column(
                children: [
                  DailyMomentumCard(
                    snapshot: value,
                    onTap: () async {
                      await context.push('/engagement-hub');
                      if (mounted) ref.invalidate(engagementSnapshotProvider);
                    },
                  ),
                  if (_loaded && _hiddenWeek != _week) ...[
                    const SizedBox(height: 12),
                    WeeklyRecapCard(
                      weeklyUnlocks: value.weeklyUnlocks,
                      currentStreak: value.currentStreak,
                      onTap: () => context.push('/weekly-recap'),
                      onDismiss: () => _dismiss(true),
                    ),
                  ],
                ],
              ),
            ];
            return LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= 900 && cards.length == 2
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards.first),
                        const SizedBox(width: 20),
                        Expanded(child: cards.last),
                      ],
                    )
                  : Column(
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
