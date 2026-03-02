import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/state/engagement_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

class EngagementHubScreen extends ConsumerStatefulWidget {
  const EngagementHubScreen({super.key});

  @override
  ConsumerState<EngagementHubScreen> createState() =>
      _EngagementHubScreenState();
}

class _EngagementHubScreenState extends ConsumerState<EngagementHubScreen> {
  bool _updatingPreferences = false;

  Future<void> _refreshAll() async {
    ref.invalidate(engagementSnapshotProvider);
    ref.invalidate(socialTargetsProvider);
    ref.invalidate(socialHighlightsProvider);
    ref.invalidate(playNextRecommendationsProvider);
    await Future.wait([
      ref.read(engagementSnapshotProvider.future),
      ref.read(socialTargetsProvider.future),
      ref.read(socialHighlightsProvider.future),
      ref.read(playNextRecommendationsProvider.future),
    ]);
  }

  Future<void> _toggleFollow(SocialTarget target) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(engagementRepositoryProvider);
    await repository.setFollowing(
      currentUserId: userId,
      targetUserId: target.userId,
      enabled: !target.isFollowing,
    );

    ref.invalidate(socialTargetsProvider);
    ref.invalidate(socialHighlightsProvider);
  }

  Future<void> _toggleWatchlist(SocialTarget target) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repository = ref.read(engagementRepositoryProvider);
    await repository.setRivalWatchlisted(
      currentUserId: userId,
      targetUserId: target.userId,
      enabled: !target.isRivalWatchlisted,
    );

    ref.invalidate(socialTargetsProvider);
    ref.invalidate(socialHighlightsProvider);
  }

  Future<void> _updatePreferences(NotificationPreferences preferences) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _updatingPreferences) return;

    setState(() => _updatingPreferences = true);
    try {
      final repository = ref.read(engagementRepositoryProvider);
      await repository.updateNotificationPreferences(
        userId: userId,
        preferences: preferences,
      );
      ref.invalidate(engagementSnapshotProvider);
    } finally {
      if (mounted) setState(() => _updatingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(engagementSnapshotProvider);
    final targetsAsync = ref.watch(socialTargetsProvider);
    final highlightsAsync = ref.watch(socialHighlightsProvider);
    final recommendationsAsync = ref.watch(playNextRecommendationsProvider);

    final isLoading =
        snapshotAsync.isLoading ||
        targetsAsync.isLoading ||
        highlightsAsync.isLoading ||
        recommendationsAsync.isLoading;

    final error =
        snapshotAsync.error ??
        targetsAsync.error ??
        highlightsAsync.error ??
        recommendationsAsync.error;

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: const Text('Engagement Hub'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load Engagement Hub\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textSecondary),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('1) Social Loop'),
                  const SizedBox(height: 8),
                  _buildSocialTargets(targetsAsync.value ?? const []),
                  const SizedBox(height: 10),
                  _buildSocialHighlights(highlightsAsync.value ?? const []),
                  const SizedBox(height: 20),
                  _buildSectionTitle('2) Challenges + Streaks'),
                  const SizedBox(height: 8),
                  _buildChallengeSummary(snapshotAsync.value!),
                  const SizedBox(height: 10),
                  _buildChallenges(snapshotAsync.value!),
                  const SizedBox(height: 10),
                  _buildNotificationPreferences(snapshotAsync.value!),
                  const SizedBox(height: 20),
                  _buildSectionTitle('3) What To Play Next'),
                  const SizedBox(height: 8),
                  _buildRecommendations(recommendationsAsync.value ?? const []),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );
  }

  Widget _buildSocialTargets(List<SocialTarget> targets) {
    if (targets.isEmpty) {
      return _panel(
        child: const Text(
          'No social targets available yet.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow + Rival Watchlist',
            style: TextStyle(color: accentPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...targets.take(8).map((target) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: target.avatarUrl != null
                              ? NetworkImage(target.avatarUrl!)
                              : null,
                          child: target.avatarUrl == null
                              ? const Icon(Icons.person, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            target.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_formatInt(target.totalStatusXp)} XP',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          selected: target.isFollowing,
                          onSelected: (_) => _toggleFollow(target),
                          label: Text(
                            target.isFollowing ? 'Following' : 'Follow',
                          ),
                          selectedColor: accentPrimary.withValues(alpha: 0.3),
                          side: BorderSide(
                            color: accentPrimary.withValues(alpha: 0.6),
                          ),
                        ),
                        FilterChip(
                          selected: target.isRivalWatchlisted,
                          onSelected: (_) => _toggleWatchlist(target),
                          label: Text(
                            target.isRivalWatchlisted
                                ? 'Watching'
                                : 'Watch Rival',
                          ),
                          selectedColor: accentSecondary.withValues(alpha: 0.3),
                          side: BorderSide(
                            color: accentSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        Chip(
                          label: Text('W +${target.weeklyGain}'),
                          backgroundColor: Colors.black.withValues(alpha: 0.25),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Chip(
                          label: Text('M +${target.monthlyGain}'),
                          backgroundColor: Colors.black.withValues(alpha: 0.25),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSocialHighlights(List<SocialHighlight> highlights) {
    if (highlights.isEmpty) {
      return _panel(
        child: const Text(
          'No activity highlights yet. Follow or watch rivals to build your feed.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    final timeFormat = DateFormat('MMM d, h:mm a');
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Highlights',
            style: TextStyle(
              color: accentSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...highlights.take(6).map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundImage: item.actorAvatarUrl != null
                      ? NetworkImage(item.actorAvatarUrl!)
                      : null,
                  child: item.actorAvatarUrl == null
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                title: Text(
                  item.storyText,
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  '${item.actorDisplayName} • ${timeFormat.format(item.createdAt.toLocal())}',
                  style: const TextStyle(color: textMuted, fontSize: 11),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChallengeSummary(EngagementSnapshot snapshot) {
    return _panel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat('Current Streak', '${snapshot.currentStreak}d'),
          _summaryStat('Best Streak', '${snapshot.longestStreak}d'),
          _summaryStat('Today', '${snapshot.todayUnlocks} unlocks'),
          _summaryStat('Today XP', snapshot.todayStatusXp.toStringAsFixed(0)),
        ],
      ),
    );
  }

  Widget _buildChallenges(EngagementSnapshot snapshot) {
    if (snapshot.challenges.isEmpty) {
      return _panel(
        child: const Text(
          'No challenges generated yet.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    return _panel(
      child: Column(
        children: snapshot.challenges.map((challenge) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.2),
                border: Border.all(
                  color: challenge.completed
                      ? accentSuccess.withValues(alpha: 0.7)
                      : Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${challenge.progress}/${challenge.target}',
                        style: const TextStyle(color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    challenge.description,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: challenge.progressFraction,
                    minHeight: 6,
                    color: challenge.completed ? accentSuccess : accentPrimary,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    challenge.completed
                        ? 'Completed • +${challenge.rewardXp} bonus XP'
                        : 'Reward: +${challenge.rewardXp} bonus XP',
                    style: TextStyle(
                      color: challenge.completed ? accentSuccess : textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationPreferences(EngagementSnapshot snapshot) {
    final preferences = snapshot.notificationPreferences;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Settings',
            style: TextStyle(color: accentWarning, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Push-ready preferences are saved now and can drive FCM/APNS delivery.',
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _prefSwitch(
            title: 'Enable Push Notifications',
            value: preferences.pushEnabled,
            onChanged: (value) =>
                _updatePreferences(preferences.copyWith(pushEnabled: value)),
          ),
          _prefSwitch(
            title: 'Rival Activity Alerts',
            value: preferences.notifyRivalActivity,
            onChanged: (value) => _updatePreferences(
              preferences.copyWith(notifyRivalActivity: value),
            ),
          ),
          _prefSwitch(
            title: 'Streak Risk Alerts',
            value: preferences.notifyStreakRisk,
            onChanged: (value) => _updatePreferences(
              preferences.copyWith(notifyStreakRisk: value),
            ),
          ),
          _prefSwitch(
            title: 'Daily Challenge Reminders',
            value: preferences.notifyDailyChallenges,
            onChanged: (value) => _updatePreferences(
              preferences.copyWith(notifyDailyChallenges: value),
            ),
          ),
          _prefSwitch(
            title: 'Activity Highlights',
            value: preferences.notifyActivityHighlights,
            onChanged: (value) => _updatePreferences(
              preferences.copyWith(notifyActivityHighlights: value),
            ),
          ),
          if (_updatingPreferences)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<PlayNextRecommendation> recommendations) {
    if (recommendations.isEmpty) {
      return _panel(
        child: const Text(
          'No recommendations available yet. Run a sync first.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    final grouped = <String, List<PlayNextRecommendation>>{};
    for (final recommendation in recommendations) {
      grouped.putIfAbsent(recommendation.recommendationType, () => []);
      grouped[recommendation.recommendationType]!.add(recommendation);
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recommendationHeader(entry.key),
                  style: const TextStyle(
                    color: accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...entry.value.map((item) => _recommendationTile(item)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _recommendationTile(PlayNextRecommendation item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.gameTitle,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.platformLabel} • ${item.completionPercentage.toStringAsFixed(1)}% complete • ${item.remainingAchievements} left',
                  style: const TextStyle(color: textMuted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  item.reason,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              final gameName = Uri.encodeComponent(item.gameTitle);
              final platformGameId = Uri.encodeComponent(item.platformGameId);
              final platform = Uri.encodeComponent(
                item.platformLabel.toLowerCase(),
              );
              context.push(
                '/game/${item.platformGameId}/achievements'
                '?name=$gameName'
                '&platform=$platform'
                '&platform_id=${item.platformId}'
                '&platform_game_id=$platformGameId',
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: accentPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _prefSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: textSecondary)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: accentPrimary,
      dense: true,
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  String _formatInt(int value) {
    final text = value.toString();
    final chars = text.split('');
    final buffer = StringBuffer();
    for (int index = 0; index < chars.length; index++) {
      final reverseIndex = chars.length - index;
      buffer.write(chars[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _recommendationHeader(String type) {
    switch (type) {
      case 'closest_completion':
        return 'Closest To Completion';
      case 'easiest_wins':
        return 'Easiest Wins';
      case 'best_xp_per_hour':
        return 'Best StatusXP / Hour';
      default:
        return 'Recommendations';
    }
  }
}
