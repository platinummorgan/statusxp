import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/achievement_comment.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Provider for loading comments for a specific achievement
final achievementCommentsProvider = FutureProvider.autoDispose.family<List<AchievementComment>, int>(
  (ref, achievementId) async {
    final service = ref.read(achievementCommentServiceProvider);
    return service.getComments(achievementId);
  },
);

/// Provider for comment count
final achievementCommentCountProvider = FutureProvider.autoDispose.family<int, int>(
  (ref, achievementId) async {
    final service = ref.read(achievementCommentServiceProvider);
    return service.getCommentCount(achievementId);
  },
);

class AchievementCommentsScreen extends ConsumerWidget {
  final int achievementId;
  final String achievementName;
  final String? achievementIconUrl;

  const AchievementCommentsScreen({
    super.key,
    required this.achievementId,
    required this.achievementName,
    this.achievementIconUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(achievementCommentsProvider(achievementId));

    return Scaffold(
      backgroundColor: const Color(0xFF0f1729),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1f3a),
        title: const Text('Comments & Tips'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Achievement header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f3a),
              border: Border(
                bottom: BorderSide(
                  color: CyberpunkTheme.neonCyan.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                if (achievementIconUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      achievementIconUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: CyberpunkTheme.neonCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.emoji_events,
                            color: CyberpunkTheme.neonCyan.withOpacity(0.5),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievementName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Community Comments & Coordination',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return _EmptyCommentsState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(achievementCommentsProvider(achievementId));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      return _CommentCard(comment: comments[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(achievementCommentsProvider(achievementId));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberpunkTheme.neonCyan,
                          foregroundColor: const Color(0xFF0f1729),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommentsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share tips or coordinate with others!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberpunkTheme.neonCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: CyberpunkTheme.neonCyan,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use comments to:',
                    style: TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Share strategies and tips\n'
                    '• Find partners for co-op/multiplayer\n'
                    '• Coordinate boosting sessions\n'
                    '• Ask for or offer help',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final AchievementComment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final timeAgo = timeago.format(comment.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1a1f3a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: CyberpunkTheme.neonCyan.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.2),
                  backgroundImage: comment.avatarUrl != null
                      ? NetworkImage(comment.avatarUrl!)
                      : null,
                  child: comment.avatarUrl == null
                      ? Icon(
                          Icons.person,
                          size: 18,
                          color: CyberpunkTheme.neonCyan,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Comment text
            Text(
              comment.commentText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
