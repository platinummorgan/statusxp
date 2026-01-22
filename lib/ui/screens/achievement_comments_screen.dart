import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/achievement_comment.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final int platformId;
  final String platformGameId;
  final String platformAchievementId;

  const AchievementCommentsScreen({
    super.key,
    required this.achievementId,
    required this.achievementName,
    this.achievementIconUrl,
    required this.platformId,
    required this.platformGameId,
    required this.platformAchievementId,
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

          // Comment input
          _CommentInput(
            achievementId: achievementId,
            platformId: platformId,
            platformGameId: platformGameId,
            platformAchievementId: platformAchievementId,
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
                  const Icon(
                    Icons.info_outline,
                    color: CyberpunkTheme.neonCyan,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
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

class _CommentCard extends ConsumerWidget {
  final AchievementComment comment;

  const _CommentCard({required this.comment});

  Future<void> _deleteComment(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1f3a),
        title: const Text(
          'Delete Comment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this comment? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(achievementCommentServiceProvider);
      await service.deleteComment(comment.id);

      // Refresh the comments list
      ref.invalidate(achievementCommentsProvider(comment.achievementId));
      ref.invalidate(achievementCommentCountProvider(comment.achievementId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comment deleted'),
            backgroundColor: CyberpunkTheme.neonCyan,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFF0f1729),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to delete: ${e.toString()}',
                    style: const TextStyle(
                      color: Color(0xFF0f1729),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAgo = timeago.format(comment.createdAt);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnComment = currentUserId == comment.userId;

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
                      ? const Icon(
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
                // Delete button (only for own comments)
                if (isOwnComment)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 20,
                    color: Colors.white.withOpacity(0.4),
                    onPressed: () => _deleteComment(context, ref),
                    tooltip: 'Delete comment',
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

class _CommentInput extends ConsumerStatefulWidget {
  final int achievementId;
  final int platformId;
  final String platformGameId;
  final String platformAchievementId;

  const _CommentInput({
    required this.achievementId,
    required this.platformId,
    required this.platformGameId,
    required this.platformAchievementId,
  });

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isPosting = false;
  static const int _maxLength = 500;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || text.length > _maxLength || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      final service = ref.read(achievementCommentServiceProvider);
      await service.postComment(
        achievementId: widget.achievementId,
        commentText: text,
        platformId: widget.platformId,
        platformGameId: widget.platformGameId,
        platformAchievementId: widget.platformAchievementId,
      );

      // Clear input
      _textController.clear();
      _focusNode.unfocus();

      // Refresh comments list
      ref.invalidate(achievementCommentsProvider(widget.achievementId));
      ref.invalidate(achievementCommentCountProvider(widget.achievementId));

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            backgroundColor: CyberpunkTheme.neonCyan,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFF0f1729),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(
                      color: Color(0xFF0f1729),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        border: Border(
          top: BorderSide(
            color: CyberpunkTheme.neonCyan.withOpacity(0.2),
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !_isPosting,
                maxLines: 3,
                minLines: 1,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Share a tip or coordinate...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0f1729),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: CyberpunkTheme.neonCyan,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  counterStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Rebuild to update button state
                },
                onSubmitted: (_) => _postComment(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _textController.text.trim().isEmpty || _isPosting
                  ? null
                  : _postComment,
              icon: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CyberpunkTheme.neonCyan,
                        ),
                      ),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: _textController.text.trim().isEmpty
                    ? CyberpunkTheme.neonCyan.withOpacity(0.2)
                    : CyberpunkTheme.neonCyan,
                foregroundColor: _textController.text.trim().isEmpty
                    ? CyberpunkTheme.neonCyan.withOpacity(0.5)
                    : const Color(0xFF0f1729),
                disabledBackgroundColor:
                    CyberpunkTheme.neonCyan.withOpacity(0.2),
                disabledForegroundColor:
                    CyberpunkTheme.neonCyan.withOpacity(0.5),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
