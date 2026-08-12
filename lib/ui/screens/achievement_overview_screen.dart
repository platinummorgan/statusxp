import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/achievement_comment.dart';
import 'package:statusxp/domain/achievement_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

final compositeAchievementCommentsProvider = FutureProvider.autoDispose
    .family<List<AchievementComment>, AchievementRef>((ref, achievementRef) {
      return ref
          .watch(achievementCommentServiceProvider)
          .getCommentsForComposite(achievementRef);
    });

class AchievementOverviewScreen extends ConsumerStatefulWidget {
  final AchievementRef achievementRef;
  const AchievementOverviewScreen({super.key, required this.achievementRef});

  @override
  ConsumerState<AchievementOverviewScreen> createState() =>
      _AchievementOverviewScreenState();
}

class _AchievementOverviewScreenState
    extends ConsumerState<AchievementOverviewScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logCustomEvent(
      eventName: 'achievement_overview_viewed',
      parameters: {
        'platform_id': widget.achievementRef.gameRef.platformId,
        'platform_game_id': widget.achievementRef.gameRef.platformGameId,
        'platform_achievement_id': widget.achievementRef.platformAchievementId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(achievementOverviewProvider(widget.achievementRef));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('ACHIEVEMENT'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(widget.achievementRef.gameRef.location),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: item.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _StateMessage(
            title: 'Unable to load this achievement',
            message: error.toString(),
            onRetry: () => ref.invalidate(
              achievementOverviewProvider(widget.achievementRef),
            ),
          ),
          data: (achievement) => achievement == null
              ? _StateMessage(
                  title: 'Achievement not found',
                  message:
                      'This achievement may have changed or the link is incorrect.',
                  onRetry: () =>
                      context.go(widget.achievementRef.gameRef.location),
                  actionLabel: 'Back to game',
                )
              : _AchievementBody(achievement: achievement),
        ),
      ),
    );
  }
}

class _AchievementBody extends ConsumerWidget {
  final AchievementOverview achievement;
  const _AchievementBody({required this.achievement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(
      compositeAchievementCommentsProvider(achievement.ref),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => context.go(achievement.ref.gameRef.location),
                icon: const Icon(Icons.videogame_asset_outlined),
                label: Text(achievement.gameName),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFF151A35),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      final icon = _AchievementIcon(url: achievement.iconUrl);
                      final details = _Details(achievement: achievement);
                      return compact
                          ? Column(
                              children: [
                                icon,
                                const SizedBox(height: 20),
                                details,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                icon,
                                const SizedBox(width: 24),
                                Expanded(child: details),
                              ],
                            );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/coop-partners'),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Find co-op help'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'COMMUNITY TIPS & COMMENTS',
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              comments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _InlineMessage(
                  text: 'Comments could not be loaded.',
                  onRetry: () => ref.invalidate(
                    compositeAchievementCommentsProvider(achievement.ref),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const _InlineMessage(
                        text: 'No community tips have been posted yet.',
                      )
                    : Column(
                        children: items.take(10).map(_CommentCard.new).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  final String? url;
  const _AchievementIcon({this.url});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: 150,
      height: 150,
      child: url == null || url!.isEmpty
          ? const ColoredBox(
              color: Color(0xFF0A0E27),
              child: Icon(Icons.emoji_events, size: 64, color: Colors.white24),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF0A0E27),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 56,
                  color: Colors.white24,
                ),
              ),
            ),
    ),
  );
}

class _Details extends StatelessWidget {
  final AchievementOverview achievement;
  const _Details({required this.achievement});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        achievement.name,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (achievement.description?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(
          achievement.description!,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (achievement.rarityGlobal != null)
            Chip(
              label: Text(
                '${achievement.rarityGlobal!.toStringAsFixed(2)}% rarity',
              ),
            ),
          Chip(
            label: Text('${achievement.statusXP.toStringAsFixed(1)} StatusXP'),
          ),
          if (achievement.scoreValue > 0)
            Chip(label: Text('${achievement.scoreValue} points')),
          if (achievement.isPlatinum) const Chip(label: Text('Platinum')),
          if (achievement.isHidden) const Chip(label: Text('Hidden')),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        achievement.isEarned
            ? 'Earned ${DateFormat.yMMMd().add_jm().format(achievement.earnedAt!.toLocal())}'
            : 'Not earned yet',
        style: TextStyle(
          color: achievement.isEarned ? Colors.greenAccent : Colors.white54,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _CommentCard extends StatelessWidget {
  final AchievementComment comment;
  const _CommentCard(this.comment);
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF151A35),
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: comment.avatarUrl == null
            ? null
            : NetworkImage(comment.avatarUrl!),
        child: comment.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(comment.displayName ?? comment.username ?? 'Player'),
      subtitle: Text(comment.commentText),
      trailing: Text(
        timeago.format(comment.createdAt),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _InlineMessage({required this.text, this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF151A35),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;
  const _StateMessage({
    required this.title,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Try again',
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
