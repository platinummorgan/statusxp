import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when sync is rate limited
class XboxRateLimitException implements Exception {
  final String message;
  final DateTime? nextSyncAvailableAt;

  XboxRateLimitException(this.message, {this.nextSyncAvailableAt});

  @override
  String toString() => message;
}

/// Service for Xbox Live integration
class XboxService {
  final SupabaseClient _client;

  XboxService(this._client);

  /// Link Xbox account using Microsoft OAuth
  Future<XboxLinkResult> linkAccount(String authCode) async {
    final response = await _client.functions.invoke(
      'xbox-link-account',
      body: {
        'authCode': authCode,
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to link Xbox account';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return XboxLinkResult(
      success: data['success'] as bool,
      xuid: data['xuid'] as String,
      gamertag: data['gamertag'] as String,
      gamerscore: data['gamerscore'] as int,
      totalAchievements: data['totalAchievements'] as int,
    );
  }

  /// Start syncing achievement data from Xbox Live
  Future<XboxSyncStartResult> startSync({
    String syncType = 'full',
    bool forceResync = false,
  }) async {
    final response = await _client.functions.invoke(
      'xbox-start-sync',
      body: {
        'syncType': syncType,
        'forceResync': forceResync,
      },
    );

    // Handle rate limiting (429)
    if (response.status == 429) {
      final data = response.data as Map<String, dynamic>;
      final nextSyncStr = data['nextSyncAvailableAt'] as String?;
      final nextSyncAt = nextSyncStr != null ? DateTime.parse(nextSyncStr) : null;
      
      throw XboxRateLimitException(
        data['message'] as String? ?? 'Sync cooldown active',
        nextSyncAvailableAt: nextSyncAt,
      );
    }

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to start sync';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return XboxSyncStartResult(
      success: data['success'] as bool,
      syncLogId: data['syncLogId'] as int,
      message: data['message'] as String,
    );
  }

  /// Continue syncing from where it left off (processes next batch)
  Future<XboxSyncStartResult> continueSync() async {
    return startSync(); // Same endpoint, it will resume from last position
  }

  /// Stop current sync (keeps progress)
  Future<void> stopSync() async {
    final response = await _client.functions.invoke('xbox-stop-sync');

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to stop sync';
      throw Exception(error);
    }
  }

  /// Get current sync status
  Future<XboxSyncStatus> getSyncStatus() async {
    final response = await _client.functions.invoke('xbox-sync-status');

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to get sync status';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return XboxSyncStatus.fromJson(data);
  }

  /// Stream sync status updates (polls every 2 seconds during sync)
  Stream<XboxSyncStatus> watchSyncStatus() async* {
    while (true) {
      final status = await getSyncStatus();
      yield status;

      // If sync is in progress, poll more frequently
      if (status.status == 'syncing' || status.status == 'pending') {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        // If not syncing, poll less frequently
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }
}

/// Result from linking Xbox account
class XboxLinkResult {
  final bool success;
  final String xuid;
  final String gamertag;
  final int gamerscore;
  final int totalAchievements;

  XboxLinkResult({
    required this.success,
    required this.xuid,
    required this.gamertag,
    required this.gamerscore,
    required this.totalAchievements,
  });
}

/// Result from starting sync
class XboxSyncStartResult {
  final bool success;
  final int syncLogId;
  final String message;

  XboxSyncStartResult({
    required this.success,
    required this.syncLogId,
    required this.message,
  });
}

/// Current sync status
class XboxSyncStatus {
  final bool isLinked;
  final String status; // never_synced, pending, syncing, success, error
  final int progress;
  final String? error;
  final DateTime? lastSyncAt;
  final String? lastSyncText;
  final XboxSyncLog? latestLog;

  XboxSyncStatus({
    required this.isLinked,
    required this.status,
    required this.progress,
    this.error,
    this.lastSyncAt,
    this.lastSyncText,
    this.latestLog,
  });

  factory XboxSyncStatus.fromJson(Map<String, dynamic> json) {
    return XboxSyncStatus(
      isLinked: json['isLinked'] as bool,
      status: json['status'] as String,
      progress: json['progress'] as int? ?? 0,
      error: json['error'] as String?,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      lastSyncText: json['lastSyncText'] as String?,
      latestLog: json['latestLog'] != null
          ? XboxSyncLog.fromJson(json['latestLog'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isSyncing => status == 'syncing';
  bool get isPending => status == 'pending';
  bool get hasError => status == 'error';
  bool get isSuccess => status == 'success';
  bool get neverSynced => status == 'never_synced';
}

/// Sync log entry
class XboxSyncLog {
  final int id;
  final String syncType;
  final String status;
  final int gamesProcessed;
  final int gamesTotal;
  final int achievementsAdded;
  final int achievementsUpdated;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  XboxSyncLog({
    required this.id,
    required this.syncType,
    required this.status,
    required this.gamesProcessed,
    required this.gamesTotal,
    required this.achievementsAdded,
    required this.achievementsUpdated,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  factory XboxSyncLog.fromJson(Map<String, dynamic> json) {
    return XboxSyncLog(
      id: json['id'] as int,
      syncType: json['syncType'] as String,
      status: json['status'] as String,
      gamesProcessed: json['gamesProcessed'] as int? ?? 0,
      gamesTotal: json['gamesTotal'] as int? ?? 0,
      achievementsAdded: json['achievementsAdded'] as int? ?? 0,
      achievementsUpdated: json['achievementsUpdated'] as int? ?? 0,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  double get progressPercent {
    if (gamesTotal == 0) return 0;
    return (gamesProcessed / gamesTotal) * 100;
  }
}
