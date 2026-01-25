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
    
    // Check if confirmation is required
    if (data['requiresConfirmation'] == true) {
      return PSNLinkResult(
        success: false,
        requiresConfirmation: true,
        existingUserId: data['existingUserId'] as String,
        platform: data['platform'] as String,
        username: data['username'] as String,
        message: data['message'] as String,
        credentials: data['credentials'],
      );
    }
    
    return PSNLinkResult(
      success: data['success'] as bool,
      accountId: data['accountId'] as String,
      trophyLevel: data['trophyLevel'] as int,
      totalTrophies: data['totalTrophies'] as int,
    );
  }
  
  /// Confirm and execute account merge
  Future<void> confirmMerge(String existingUserId, Map<String, dynamic> credentials) async {
    final response = await _client.functions.invoke(
      'psn-confirm-merge',
      body: {
        'existingUserId': existingUserId,
        'credentials': credentials,
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Failed to merge accounts';
      throw Exception(error);
    }
  }

  /// Start syncing trophy data from PSN
  Future<PSNSyncStartResult> startSync({
    String syncType = 'full',
    bool forceResync = false,
    bool isAutoSync = false,
  }) async {
    final response = await _client.functions.invoke(
      'psn-start-sync',
      body: {
        'syncType': syncType,
        'forceResync': forceResync,
        'isAutoSync': isAutoSync,
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
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client.functions.invoke(
      'psn-stop-sync',
      body: {'userId': userId},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Failed to stop sync';
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
    
    // Don't refresh session here - it's handled by AuthRefreshService
    // Polling this every 2-10 seconds causes refresh spam
    
    // Retry logic for DNS/network failures when app resumes from background
    int retries = 0;
    const maxRetries = 3;
    Exception? lastError;

    while (retries < maxRetries) {
      try {
        final response = await _client.functions.invoke('psn-sync-status');

        if (response.status != 200) {
          final error = response.data['error'] ?? 'Failed to get sync status';
          throw Exception('Status ${ response.status}: $error');
        }

        final data = response.data as Map<String, dynamic>;
        return PSNSyncStatus.fromJson(data);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        
        // Only retry on DNS/network errors
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated')) {
          retries++;
          if (retries < maxRetries) {
            // Exponential backoff: 500ms, 1s, 2s
            await Future.delayed(Duration(milliseconds: 500 * (1 << (retries - 1))));
            continue;
          }
        }
        // Non-network errors or max retries reached
        throw lastError;
      }
    }

    throw lastError ?? Exception('Failed to get sync status after $maxRetries retries');
  }

  /// Stream sync status updates (polls every 2 seconds during sync)
  Stream<PSNSyncStatus> watchSyncStatus() async* {
    PSNSyncStatus? lastStatus;

    while (true) {
      try {
        final status = await getSyncStatus();
        lastStatus = status;
        yield status;

        // If sync is in progress, poll more frequently
        if (status.status == 'syncing' || status.status == 'pending') {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // If not syncing, poll less frequently
          await Future.delayed(const Duration(seconds: 10));
        }
      } catch (_) {
        // If actively syncing, retry silently without showing errors to the UI
        final previous = lastStatus;
        if (previous != null && (previous.status == 'syncing' || previous.status == 'pending')) {
          // Just retry without yielding—user doesn't need to see transient network blips
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        // For non-syncing states, keep last known state without error
        final fallback = previous != null
            ? PSNSyncStatus(
                isLinked: previous.isLinked,
                status: previous.status,
                progress: previous.progress,
                error: null,
                lastSyncAt: previous.lastSyncAt,
                lastSyncText: previous.lastSyncText,
                latestLog: previous.latestLog,
                isAutoSync: previous.isAutoSync,
              )
            : PSNSyncStatus(
                isLinked: false,
                status: 'error',
                progress: 0,
                error: null,
                lastSyncAt: null,
                lastSyncText: null,
                latestLog: null,
                isAutoSync: false,
              );

        yield fallback;
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }
}

/// Result from linking PSN account
class PSNLinkResult {
  final bool success;
  final String? accountId;
  final int? trophyLevel;
  final int? totalTrophies;
  final bool requiresConfirmation;
  final String? existingUserId;
  final String? platform;
  final String? username;
  final String? message;
  final Map<String, dynamic>? credentials;

  PSNLinkResult({
    required this.success,
    this.accountId,
    this.trophyLevel,
    this.totalTrophies,
    this.requiresConfirmation = false,
    this.existingUserId,
    this.platform,
    this.username,
    this.message,
    this.credentials,
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
  final bool isAutoSync; // Is this an auto-sync (not rate limited)

  PSNSyncStatus({
    required this.isLinked,
    required this.status,
    required this.progress,
    this.error,
    this.lastSyncAt,
    this.lastSyncText,
    this.latestLog,
    this.isAutoSync = false,
  });

  factory PSNSyncStatus.fromJson(Map<String, dynamic> json) {
    return PSNSyncStatus(
      isLinked: json['isLinked'] as bool,
      status: json['status'] as String? ?? 'never_synced',
      progress: json['progress'] as int? ?? 0,
      error: json['error'] as String?,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      lastSyncText: json['lastSyncText'] as String?,
      latestLog: json['latestLog'] != null
          ? PSNSyncLog.fromJson(json['latestLog'] as Map<String, dynamic>)
          : null,
      isAutoSync: json['isAutoSync'] as bool? ?? false,
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
