class SyncIssueAnalysis {
  final String effectiveStatus;
  final String? effectiveErrorMessage;
  final String? warningMessage;
  final String category;
  final bool requiresRelink;

  const SyncIssueAnalysis({
    required this.effectiveStatus,
    required this.effectiveErrorMessage,
    required this.warningMessage,
    required this.category,
    required this.requiresRelink,
  });
}

/// Classifies sync failures so all platform screens show consistent guidance.
class SyncIssueClassifier {
  static const List<String> _relinkMarkers = [
    'relink',
    'invalid_client',
    'invalid client',
    'refresh token',
    'token expired',
    'expired token',
    'expired',
    'unauthorized',
    'forbidden',
    'invalid_grant',
  ];

  static const List<String> _rateLimitMarkers = [
    'rate limit',
    'too many requests',
    'cooldown',
    'try again later',
    '429',
  ];

  static const List<String> _networkMarkers = [
    'socketexception',
    'failed host lookup',
    'no address associated',
    'connection reset',
    'timed out',
    'network',
  ];

  static SyncIssueAnalysis analyze({
    required String platformName,
    required String? syncStatus,
    required String? errorMessage,
    bool requiresRelinkSignal = false,
  }) {
    final normalizedStatus = syncStatus ?? 'never_synced';
    final lower = errorMessage?.toLowerCase() ?? '';
    final hasError = lower.trim().isNotEmpty;

    final requiresRelink =
        requiresRelinkSignal || _containsAny(lower, _relinkMarkers);
    final isRateLimited = _containsAny(lower, _rateLimitMarkers);
    final isNetworkError = _containsAny(lower, _networkMarkers);

    if (requiresRelink) {
      return SyncIssueAnalysis(
        effectiveStatus: normalizedStatus == 'success'
            ? 'error'
            : normalizedStatus,
        effectiveErrorMessage: errorMessage,
        warningMessage:
            '$platformName link expired. Go to Settings, disconnect, then reconnect.',
        category: 'relink_required',
        requiresRelink: true,
      );
    }

    if (isRateLimited) {
      return SyncIssueAnalysis(
        effectiveStatus: normalizedStatus,
        effectiveErrorMessage: errorMessage,
        warningMessage: null,
        category: 'rate_limited',
        requiresRelink: false,
      );
    }

    if (hasError && isNetworkError) {
      return SyncIssueAnalysis(
        effectiveStatus: normalizedStatus,
        effectiveErrorMessage: errorMessage,
        warningMessage: null,
        category: 'network_error',
        requiresRelink: false,
      );
    }

    if (hasError) {
      return SyncIssueAnalysis(
        effectiveStatus: normalizedStatus,
        effectiveErrorMessage: errorMessage,
        warningMessage: null,
        category: 'sync_error',
        requiresRelink: false,
      );
    }

    return SyncIssueAnalysis(
      effectiveStatus: normalizedStatus,
      effectiveErrorMessage: errorMessage,
      warningMessage: null,
      category: 'none',
      requiresRelink: false,
    );
  }

  static bool hasNoFreshWrite({
    required DateTime? syncStartedAt,
    required DateTime? previousLastSyncAt,
    required DateTime? currentLastSyncAt,
  }) {
    if (syncStartedAt == null || currentLastSyncAt == null) {
      return false;
    }

    if (previousLastSyncAt != null &&
        !currentLastSyncAt.isAfter(previousLastSyncAt)) {
      return true;
    }

    // Allow slight server/client clock skew before flagging.
    return currentLastSyncAt.isBefore(
      syncStartedAt.subtract(const Duration(seconds: 15)),
    );
  }

  static String noFreshWriteWarning(String platformName) {
    return '$platformName sync completed, but no fresh data write was detected. If this continues, disconnect and reconnect this platform.';
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final marker in needles) {
      if (haystack.contains(marker)) {
        return true;
      }
    }
    return false;
  }
}
