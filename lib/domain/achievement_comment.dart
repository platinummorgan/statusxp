class AchievementComment {
  final String id;
  final int achievementId;
  final String userId;
  final String commentText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isHidden;
  final bool isFlagged;
  final int flagCount;
  
  // Joined from profiles table
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  AchievementComment({
    required this.id,
    required this.achievementId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    required this.updatedAt,
    required this.isHidden,
    required this.isFlagged,
    required this.flagCount,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory AchievementComment.fromJson(Map<String, dynamic> json) {
    return AchievementComment(
      id: json['id'] as String,
      achievementId: json['achievement_id'] as int,
      userId: json['user_id'] as String,
      commentText: json['comment_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isHidden: json['is_hidden'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagCount: json['flag_count'] as int? ?? 0,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'achievement_id': achievementId,
      'user_id': userId,
      'comment_text': commentText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_hidden': isHidden,
      'is_flagged': isFlagged,
      'flag_count': flagCount,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }

  AchievementComment copyWith({
    String? id,
    int? achievementId,
    String? userId,
    String? commentText,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isHidden,
    bool? isFlagged,
    int? flagCount,
    String? username,
    String? displayName,
    String? avatarUrl,
  }) {
    return AchievementComment(
      id: id ?? this.id,
      achievementId: achievementId ?? this.achievementId,
      userId: userId ?? this.userId,
      commentText: commentText ?? this.commentText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isHidden: isHidden ?? this.isHidden,
      isFlagged: isFlagged ?? this.isFlagged,
      flagCount: flagCount ?? this.flagCount,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Get display name for UI - prefers displayName, falls back to username
  String get userDisplayName => displayName ?? username ?? 'User';
}
