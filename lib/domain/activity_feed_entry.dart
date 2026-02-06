/// Represents a single activity feed story
class ActivityFeedEntry {
  final int id;
  final String userId;
  final String storyText;
  final String eventType;
  final String username;
  final String? avatarUrl;
  final String? gameTitle;
  final DateTime createdAt;
  final int? oldValue;
  final int? newValue;
  final int? changeAmount;
  final int goldCount;
  final int silverCount;
  final int bronzeCount;

  const ActivityFeedEntry({
    required this.id,
    required this.userId,
    required this.storyText,
    required this.eventType,
    required this.username,
    this.avatarUrl,
    this.gameTitle,
    required this.createdAt,
    this.oldValue,
    this.newValue,
    this.changeAmount,
    this.goldCount = 0,
    this.silverCount = 0,
    this.bronzeCount = 0,
  });

  factory ActivityFeedEntry.fromJson(Map<String, dynamic> json) {
    return ActivityFeedEntry(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      storyText: json['story_text'] as String,
      eventType: json['event_type'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      gameTitle: json['game_title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      oldValue: json['old_value'] as int?,
      newValue: json['new_value'] as int?,
      changeAmount: json['change_amount'] as int?,
      goldCount: (json['gold_count'] as int?) ?? 0,
      silverCount: (json['silver_count'] as int?) ?? 0,
      bronzeCount: (json['bronze_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'story_text': storyText,
      'event_type': eventType,
      'username': username,
      'avatar_url': avatarUrl,
      'game_title': gameTitle,
      'created_at': createdAt.toIso8601String(),
      'old_value': oldValue,
      'new_value': newValue,
      'change_amount': changeAmount,
      'gold_count': goldCount,
      'silver_count': silverCount,
      'bronze_count': bronzeCount,
    };
  }
}

/// Represents a grouped date with multiple stories
class ActivityFeedGroup {
  final DateTime eventDate;
  final int storyCount;
  final List<ActivityFeedEntry> stories;

  const ActivityFeedGroup({
    required this.eventDate,
    required this.storyCount,
    required this.stories,
  });

  factory ActivityFeedGroup.fromJson(Map<String, dynamic> json) {
    return ActivityFeedGroup(
      eventDate: DateTime.parse(json['event_date'] as String),
      storyCount: (json['story_count'] as num).toInt(),
      stories: (json['stories'] as List<dynamic>)
          .map((story) => ActivityFeedEntry.fromJson(story as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_date': eventDate.toIso8601String().split('T')[0],
      'story_count': storyCount,
      'stories': stories.map((s) => s.toJson()).toList(),
    };
  }
}

