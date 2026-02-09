import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/activity_feed_entry.dart';
import 'package:statusxp/data/repositories/activity_feed_repository.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// ============================================================
// PROVIDERS
// ============================================================

/// Activity Feed Repository Provider
final activityFeedRepositoryProvider = Provider<ActivityFeedRepository>((ref) {
  return ActivityFeedRepository(Supabase.instance.client);
});

/// Activity Feed Data Provider
final activityFeedProvider = FutureProvider<List<ActivityFeedGroup>>((
  ref,
) async {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return await repo.getActivityFeedGrouped(limit: 50);
});

/// Unread Count Provider
final unreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return await repo.getUnreadCount();
});

/// Stream version for realtime updates
final activityFeedStreamProvider = StreamProvider<List<ActivityFeedGroup>>((
  ref,
) {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return repo.watchActivityFeed();
});

// ============================================================
// WIDGET
// ============================================================

class ActivityFeedWidget extends ConsumerStatefulWidget {
  const ActivityFeedWidget({super.key});

  @override
  ConsumerState<ActivityFeedWidget> createState() => _ActivityFeedWidgetState();
}

class _ActivityFeedWidgetState extends ConsumerState<ActivityFeedWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Poll as a fallback when realtime events are unavailable.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(activityFeedProvider);
      ref.invalidate(unreadCountProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(activityFeedProvider);

    return Column(
      children: [
        // Clickable header - cyberpunk styled single line
        InkWell(
          onTap: () async {
            setState(() {
              _isExpanded = !_isExpanded;
            });

            // Mark as viewed when expanded
            if (_isExpanded) {
              final repo = ref.read(activityFeedRepositoryProvider);
              await repo.markAsViewed();
              // Refresh unread count
              ref.invalidate(unreadCountProvider);
            }
          },
          hoverColor: CyberpunkTheme.neonPurple.withOpacity(0.1),
          child: Stack(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CyberpunkTheme.neonPurple.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: CyberpunkTheme.neonPurple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'What are other StatusXPians up to?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // Badge indicator
                    Consumer(
                      builder: (context, ref, child) {
                        final unreadAsync = ref.watch(unreadCountProvider);
                        return unreadAsync.when(
                          data: (unreadCount) {
                            if (unreadCount == 0) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CyberpunkTheme.neonCyan,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+$unreadCount',
                                style: const TextStyle(
                                  color: CyberpunkTheme.deepBlack,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Refresh feed',
                      onPressed: () {
                        ref.invalidate(activityFeedProvider);
                        ref.invalidate(unreadCountProvider);
                      },
                      icon: const Icon(
                        Icons.refresh,
                        size: 16,
                        color: CyberpunkTheme.neonCyan,
                      ),
                    ),
                  ],
                ),
              ),
              // Shimmer effect overlay
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [
                                _shimmerAnimation.value - 0.3,
                                _shimmerAnimation.value,
                                _shimmerAnimation.value + 0.3,
                              ],
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Collapsible content
        if (_isExpanded)
          feedAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No recent activity. Sync your achievements to see updates!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return Column(
                children: [
                  const Divider(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _DateGroup(group: group);
                    },
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Failed to load activity feed: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// DATE GROUP (Collapsible by date)
// ============================================================

class _DateGroup extends StatefulWidget {
  final ActivityFeedGroup group;

  const _DateGroup({required this.group});

  @override
  State<_DateGroup> createState() => _DateGroupState();
}

class _DateGroupState extends State<_DateGroup> {
  bool _isExpanded = true; // Expand by default

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(widget.group.eventDate);

    return Column(
      children: [
        // Date header
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f3a),
              border: Border(
                bottom: BorderSide(
                  color: CyberpunkTheme.neonPurple.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: CyberpunkTheme.neonCyan,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stories list
        if (_isExpanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.group.stories.length,
            itemBuilder: (context, index) {
              final story = widget.group.stories[index];
              return _StoryTile(story: story);
            },
          ),
      ],
    );
  }
}

// ============================================================
// STORY TILE (Individual story)
// ============================================================

class _StoryTile extends StatelessWidget {
  final ActivityFeedEntry story;

  const _StoryTile({required this.story});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: story.avatarUrl != null
            ? NetworkImage(story.avatarUrl!)
            : null,
        child: story.avatarUrl == null
            ? Text(story.username[0].toUpperCase())
            : null,
      ),
      title: Text(
        story.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(story.storyText, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            _getTimeAgo(story.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
