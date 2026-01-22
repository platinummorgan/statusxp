class TrophyHelpRequest {
  final String id;
  final String userId; // Keep for backwards compatibility, use profileId for new code
  final String? profileId; // New canonical field (profiles.id)
  final String gameId;
  final String gameTitle;
  final String achievementId;
  final String achievementName;
  final String platform;
  final String? description;
  final String? availability;
  final String? platformUsername;
  final String status; // 'open', 'matched', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

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
    required this.status,
    required this.createdAt,
    required this.updatedAt,
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
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TrophyHelpResponse {
  final String id;
  final String requestId;
  final String helperUserId; // Keep for backwards compatibility, use helperProfileId for new code
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
    final helperUserId = json['helper_user_id'] as String? ?? helperProfileId ?? '';
    
    return TrophyHelpResponse(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      helperUserId: helperUserId,
      helperProfileId: helperProfileId ?? helperUserId, // Ensure helperProfileId is always set
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
      'helper_profile_id': helperProfileId ?? helperUserId, // Always include helper_profile_id
      'helper_username': helperUsername,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
