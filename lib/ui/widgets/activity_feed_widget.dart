import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/activity_feed_entry.dart';
import '../data/repositories/activity_feed_repository.dart';
import 'package:intl/intl.dart';

// ============================================================
// PROVIDERS
// ============================================================

/// Activity Feed Repository Provider
final activityFeedRepositoryProvider = Provider<ActivityFeedRepository>((ref) {
  return ActivityFeedRepository(Supabase.instance.client);
});

/// Activity Feed Data Provider
final activityFeedProvider = FutureProvider<List<ActivityFeedGroup>>((ref) async {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return await repo.getActivityFeedGrouped(limit: 50);
});

/// Unread Count Provider
final unreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return await repo.getUnreadCount();
});

/// Stream version for realtime updates
final activityFeedStreamProvider = StreamProvider<List<ActivityFeedGroup>>((ref) {
  final repo = ref.watch(activityFeedRepositoryProvider);
  return repo.watchActivityFeed();
});

// ============================================================
// WIDGET
// ============================================================

class ActivityFeedWidget extends ConsumerStatefulWidget {
  const ActivityFeedWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<ActivityFeedWidget> createState() => _ActivityFeedWidgetState();
}

class _ActivityFeedWidgetState extends ConsumerState<ActivityFeedWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(activityFeedProvider);
    final unreadAsync = ref.watch(unreadCountProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Header with unread badge
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'What are fellow StatusXP chasers up to!?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  // Unread badge
                  unreadAsync.when(
                    data: (count) {
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          
          // Collapsible content
          if (_isExpanded)
            feedAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No recent activity. Sync your achievements to see updates!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _DateGroup(group: group);
                  },
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
      ),
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
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(+${widget.group.storyCount})',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
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
          Text(
            story.storyText,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _getTimeAgo(story.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
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
