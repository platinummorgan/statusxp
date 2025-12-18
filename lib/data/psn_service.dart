import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when sync is rate limited
class PSNRateLimitException implements Exception {
  final String message;
  final DateTime? nextSyncAvailableAt;

  PSNRateLimitException(this.message, {this.nextSyncAvailableAt});

  @override
  String toString() => message;
}

/// Service for PlayStation Network integration
class PSNService {
  final SupabaseClient _client;

  PSNService(this._client);

  /// Link PSN account using NPSSO token
  Future<PSNLinkResult> linkAccount(String npssoToken) async {
    final response = await _client.functions.invoke(
      'psn-link-account',
      body: {
        'npssoToken': npssoToken,
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to link PSN account';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return PSNLinkResult(
      success: data['success'] as bool,
      accountId: data['accountId'] as String,
      trophyLevel: data['trophyLevel'] as int,
      totalTrophies: data['totalTrophies'] as int,
    );
  }

  /// Start syncing trophy data from PSN
  Future<PSNSyncStartResult> startSync({
    String syncType = 'full',
    bool forceResync = false,
  }) async {
    final response = await _client.functions.invoke(
      'psn-start-sync',
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
      
      throw PSNRateLimitException(
        data['message'] as String? ?? 'Sync cooldown active',
        nextSyncAvailableAt: nextSyncAt,
      );
    }

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to start sync';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return PSNSyncStartResult(
      success: data['success'] as bool,
      syncLogId: data['syncLogId'] as int,
      message: data['message'] as String,
    );
  }

  /// Continue syncing from where it left off (processes next batch)
  Future<PSNSyncStartResult> continueSync() async {
    return startSync(); // Same endpoint, it will resume from last position
  }

  /// Stop current sync (keeps progress)
  Future<void> stopSync() async {
    final response = await _client.functions.invoke('psn-stop-sync');

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to stop sync';
      throw Exception(error);
    }
  }

  /// Get current sync status
  Future<PSNSyncStatus> getSyncStatus() async {
    // Check if user is authenticated
    final user = _client.auth.currentUser;
    if (user == null) {
      // Return default status instead of throwing
      return PSNSyncStatus(
        isLinked: false,
        status: 'error',
        progress: 0,
        error: 'Not authenticated. Please sign in.',
        lastSyncAt: null,
        latestLog: null,
      );
    }
    
    // Try to refresh session
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      return PSNSyncStatus(
        isLinked: false,
        status: 'error',
        progress: 0,
        error: 'Session expired. Please sign in again.',
        lastSyncAt: null,
        latestLog: null,
      );
    }

    final response = await _client.functions.invoke('psn-sync-status');

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to get sync status';
      throw Exception('Status ${ response.status}: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return PSNSyncStatus.fromJson(data);
  }

  /// Stream sync status updates (polls every 2 seconds during sync)
  Stream<PSNSyncStatus> watchSyncStatus() async* {
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

/// Result from linking PSN account
class PSNLinkResult {
  final bool success;
  final String accountId;
  final int trophyLevel;
  final int totalTrophies;

  PSNLinkResult({
    required this.success,
    required this.accountId,
    required this.trophyLevel,
    required this.totalTrophies,
  });
}

/// Result from starting sync
class PSNSyncStartResult {
  final bool success;
  final int syncLogId;
  final String message;

  PSNSyncStartResult({
    required this.success,
    required this.syncLogId,
    required this.message,
  });
}

/// Current sync status
class PSNSyncStatus {
  final bool isLinked;
  final String status; // never_synced, pending, syncing, success, error
  final int progress;
  final String? error;
  final DateTime? lastSyncAt;
  final String? lastSyncText;
  final PSNSyncLog? latestLog;

  PSNSyncStatus({
    required this.isLinked,
    required this.status,
    required this.progress,
    this.error,
    this.lastSyncAt,
    this.lastSyncText,
    this.latestLog,
  });

  factory PSNSyncStatus.fromJson(Map<String, dynamic> json) {
    return PSNSyncStatus(
      isLinked: json['isLinked'] as bool,
      status: json['status'] as String,
      progress: json['progress'] as int? ?? 0,
      error: json['error'] as String?,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      lastSyncText: json['lastSyncText'] as String?,
      latestLog: json['latestLog'] != null
          ? PSNSyncLog.fromJson(json['latestLog'] as Map<String, dynamic>)
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
class PSNSyncLog {
  final int id;
  final String syncType;
  final String status;
  final int gamesProcessed;
  final int gamesTotal;
  final int trophiesAdded;
  final int trophiesUpdated;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  PSNSyncLog({
    required this.id,
    required this.syncType,
    required this.status,
    required this.gamesProcessed,
    required this.gamesTotal,
    required this.trophiesAdded,
    required this.trophiesUpdated,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  factory PSNSyncLog.fromJson(Map<String, dynamic> json) {
    return PSNSyncLog(
      id: json['id'] as int,
      syncType: json['syncType'] as String,
      status: json['status'] as String,
      gamesProcessed: json['gamesProcessed'] as int? ?? 0,
      gamesTotal: json['gamesTotal'] as int? ?? 0,
      trophiesAdded: json['trophiesAdded'] as int? ?? 0,
      trophiesUpdated: json['trophiesUpdated'] as int? ?? 0,
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
