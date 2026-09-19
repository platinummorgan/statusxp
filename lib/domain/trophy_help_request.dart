class TrophyHelpRequest {
  final String id;
  final String
  userId; // Keep for backwards compatibility, use profileId for new code
  final String? profileId; // New canonical field (profiles.id)
  final String gameId;
  final String gameTitle;
  final String achievementId;
  final String achievementName;
  final String platform;
  final String? description;
  final String? availability;
  final String? platformUsername;
  final DateTime? scheduledAt;
  final int? sessionUtcOffsetMinutes;
  final int helpersNeeded;
  final String status; // 'open', 'matched', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConfirmedAt;
  final int scheduleRevision;
  final DateTime? scheduleChangedAt;

  bool needsConfirmation(DateTime now) =>
      status == 'open' &&
      (now.difference(lastConfirmedAt ?? createdAt).inDays >= 30 ||
          (scheduledAt != null && scheduledAt!.isBefore(now)));

  TrophyHelpRequest({
    required this.id,
    required this.userId,
    this.profileId,
    required this.gameId,
    required this.gameTitle,
    required this.achievementId,
    required this.achievementName,
    required this.platform,
    this.description,
    this.availability,
    this.platformUsername,
    this.scheduledAt,
    this.sessionUtcOffsetMinutes,
    this.helpersNeeded = 1,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastConfirmedAt,
    this.scheduleRevision = 0,
    this.scheduleChangedAt,
  });

  factory TrophyHelpRequest.fromJson(Map<String, dynamic> json) {
    // Prefer profile_id if present, fallback to user_id for backwards compatibility
    final profileId = json['profile_id'] as String?;
    final userId = json['user_id'] as String? ?? profileId ?? '';

    return TrophyHelpRequest(
      id: json['id'] as String,
      userId: userId,
      profileId: profileId ?? userId, // Ensure profileId is always set
      gameId: json['game_id'] as String,
      gameTitle: json['game_title'] as String,
      achievementId: json['achievement_id'] as String,
      achievementName: json['achievement_name'] as String,
      platform: json['platform'] as String,
      description: json['description'] as String?,
      availability: json['availability'] as String?,
      platformUsername: json['platform_username'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? ''),
      sessionUtcOffsetMinutes: json['session_utc_offset_minutes'] as int?,
      helpersNeeded: json['helpers_needed'] as int? ?? 1,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      scheduleRevision: json['schedule_revision'] as int? ?? 0,
      scheduleChangedAt: DateTime.tryParse(
        json['schedule_changed_at'] as String? ?? '',
      ),
      lastConfirmedAt: DateTime.tryParse(
        json['last_confirmed_at'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'profile_id': profileId ?? userId, // Always include profile_id
      'game_id': gameId,
      'game_title': gameTitle,
      'achievement_id': achievementId,
      'achievement_name': achievementName,
      'platform': platform,
      'description': description,
      'availability': availability,
      'platform_username': platformUsername,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'session_utc_offset_minutes': sessionUtcOffsetMinutes,
      'helpers_needed': helpersNeeded,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'schedule_revision': scheduleRevision,
      'schedule_changed_at': scheduleChangedAt?.toUtc().toIso8601String(),
      'last_confirmed_at': lastConfirmedAt?.toUtc().toIso8601String(),
    };
  }

  TrophyHelpRequest copyWith({
    String? id,
    String? userId,
    String? profileId,
    String? gameId,
    String? gameTitle,
    String? achievementId,
    String? achievementName,
    String? platform,
    String? description,
    String? availability,
    String? platformUsername,
    DateTime? scheduledAt,
    int? sessionUtcOffsetMinutes,
    int? helpersNeeded,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastConfirmedAt,
    int? scheduleRevision,
    DateTime? scheduleChangedAt,
  }) {
    return TrophyHelpRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      gameId: gameId ?? this.gameId,
      gameTitle: gameTitle ?? this.gameTitle,
      achievementId: achievementId ?? this.achievementId,
      achievementName: achievementName ?? this.achievementName,
      platform: platform ?? this.platform,
      description: description ?? this.description,
      availability: availability ?? this.availability,
      platformUsername: platformUsername ?? this.platformUsername,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sessionUtcOffsetMinutes:
          sessionUtcOffsetMinutes ?? this.sessionUtcOffsetMinutes,
      helpersNeeded: helpersNeeded ?? this.helpersNeeded,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      scheduleRevision: scheduleRevision ?? this.scheduleRevision,
      scheduleChangedAt: scheduleChangedAt ?? this.scheduleChangedAt,
    );
  }
}

class TrophyHelpResponse {
  final String id;
  final String requestId;
  final String
  helperUserId; // Keep for backwards compatibility, use helperProfileId for new code
  final String? helperProfileId; // New canonical field (profiles.id)
  final String? helperUsername; // Helper's username from profiles table
  final String? helperPsnOnlineId; // Helper's PSN username
  final String? helperXboxGamertag; // Helper's Xbox gamertag
  final String? helperSteamId; // Helper's Steam ID
  final String? message;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  TrophyHelpResponse({
    required this.id,
    required this.requestId,
    required this.helperUserId,
    this.helperProfileId,
    this.helperUsername,
    this.helperPsnOnlineId,
    this.helperXboxGamertag,
    this.helperSteamId,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory TrophyHelpResponse.fromJson(Map<String, dynamic> json) {
    // Prefer helper_profile_id if present, fallback to helper_user_id for backwards compatibility
    final helperProfileId = json['helper_profile_id'] as String?;
    final helperUserId =
        json['helper_user_id'] as String? ?? helperProfileId ?? '';

    return TrophyHelpResponse(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      helperUserId: helperUserId,
      helperProfileId:
          helperProfileId ??
          helperUserId, // Ensure helperProfileId is always set
      helperUsername: json['helper_username'] as String?,
      helperPsnOnlineId: json['helper_psn_online_id'] as String?,
      helperXboxGamertag: json['helper_xbox_gamertag'] as String?,
      helperSteamId: json['helper_steam_id'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'helper_user_id': helperUserId,
      'helper_profile_id':
          helperProfileId ?? helperUserId, // Always include helper_profile_id
      'helper_username': helperUsername,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
