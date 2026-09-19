import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/domain/coop_feedback.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

enum CoopFeed { discover, requests, offers }

typedef CoopGameKey = ({String platform, String gameId});

class CoopEntry {
  const CoopEntry(this.request, {this.offerStatus});
  final TrophyHelpRequest request;
  final String? offerStatus;
}

class TrophyHelpService {
  TrophyHelpService(this._supabase);

  final SupabaseClient _supabase;

  Future<CoopFeedback?> getMyFeedback(String requestId) async {
    final row = await _supabase
        .from('coop_session_feedback')
        .select('outcome,team_again')
        .eq('request_id', requestId)
        .eq('user_id', _requireUserId())
        .maybeSingle();
    return row == null ? null : CoopFeedback.fromJson(row);
  }

  Future<void> saveFeedback(String requestId, CoopFeedback feedback) async {
    await _supabase.rpc(
      'save_coop_feedback',
      params: {
        'p_request_id': requestId,
        'p_outcome': feedback.outcome,
        'p_team_again': feedback.teamAgain,
      },
    );
  }

  /// One bounded artwork lookup for the page, independent of request loading.
  Future<Map<CoopGameKey, String>> getCoopArtwork(
    List<TrophyHelpRequest> requests,
  ) async {
    if (requests.isEmpty) return {};
    if (requests.length > 50) {
      throw ArgumentError('Artwork page exceeds 50 requests');
    }
    final wanted = requests
        .map((r) => (platform: r.platform, gameId: r.gameId))
        .toSet();
    final rows = await _supabase
        .from('games')
        .select('platform_id,platform_game_id,cover_url')
        .inFilter(
          'platform_game_id',
          wanted.map((k) => k.gameId).toSet().toList(),
        )
        .inFilter('platform_id', [1, 2, 5, 9, 4, 10, 11, 12])
        .order('platform_id');
    final covers = <CoopGameKey, String>{};
    for (final row in rows) {
      final id = row['platform_id'] as int;
      final platform = [1, 2, 5, 9].contains(id)
          ? 'psn'
          : id == 4
          ? 'steam'
          : 'xbox';
      final key = (
        platform: platform,
        gameId: row['platform_game_id'] as String,
      );
      final url = row['cover_url'] as String?;
      if (wanted.contains(key) && url != null && url.isNotEmpty) {
        covers.putIfAbsent(key, () => url);
      }
    }
    return covers;
  }

  Future<void> rescheduleRequest(
    String requestId, {
    required DateTime? scheduledAt,
    required int expectedRevision,
  }) async {
    await _supabase.rpc(
      'reschedule_coop_request',
      params: {
        'p_request_id': requestId,
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'p_utc_offset_minutes': scheduledAt?.timeZoneOffset.inMinutes,
        'p_expected_revision': expectedRevision,
      },
    );
    _invalidateOpenCache();
  }

  Future<void> reconfirmRequest(
    String requestId, {
    bool clearPastSchedule = false,
  }) async {
    await _supabase.rpc(
      'reconfirm_coop_request',
      params: {
        'p_request_id': requestId,
        'p_clear_past_schedule': clearPastSchedule,
      },
    );
    _invalidateOpenCache();
  }

  /// A fresh, bounded page. Errors propagate so the hub can offer a retry.
  Future<List<CoopEntry>> getCoopPage({
    required CoopFeed feed,
    String? platform,
    String search = '',
    int offset = 0,
    int limit = 24,
  }) async {
    if (offset < 0 || limit < 1 || limit > 50) {
      throw ArgumentError('Invalid co-op page bounds');
    }
    final offers = feed == CoopFeed.offers;
    var query = offers
        ? _supabase
              .from('trophy_help_responses')
              .select('status,request:trophy_help_requests!inner(*)')
              .eq('helper_profile_id', _requireUserId())
        : _supabase.from('trophy_help_requests').select();
    final prefix = offers ? 'request.' : '';
    if (feed == CoopFeed.discover) query = query.eq('status', 'open');
    if (feed == CoopFeed.requests) {
      query = query.eq('profile_id', _requireUserId());
    }
    if (platform != null) query = query.eq('${prefix}platform', platform);
    final term = search.trim();
    if (term.isNotEmpty) {
      // Quote the PostgREST value and escape LIKE wildcards for literal search.
      final pattern =
          '%${term.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_').replaceAll('*', '\\*')}%';
      final quoted =
          '"${pattern.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
      query = query.or(
        'game_title.ilike.$quoted,achievement_name.ilike.$quoted',
        referencedTable: offers ? 'request' : null,
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    final ownOffers = <String, String>{};
    final userId = _supabase.auth.currentUser?.id;
    if (feed == CoopFeed.discover && userId != null && rows.isNotEmpty) {
      final responses = await _supabase
          .from('trophy_help_responses')
          .select('request_id,status')
          .eq('helper_profile_id', userId)
          .inFilter('request_id', rows.map((r) => r['id']).toList())
          .order('created_at', ascending: false);
      for (final response in responses) {
        ownOffers.putIfAbsent(
          response['request_id'] as String,
          () => response['status'] as String,
        );
      }
    }
    return rows
        .map(
          (row) => CoopEntry(
            TrophyHelpRequest.fromJson(
              offers ? row['request'] as Map<String, dynamic> : row,
            ),
            offerStatus: offers
                ? row['status'] as String?
                : ownOffers[row['id']],
          ),
        )
        .toList();
  }

  // ------------------------------
  // Cache / de-dupe settings
  // ------------------------------

  static const Duration _openRequestsTtl = Duration(seconds: 5);

  // Cache open requests by (platform, gameId)
  final Map<_OpenKey, _CacheEntry<List<TrophyHelpRequest>>> _openCache = {};

  // In-flight de-dupe so repeated calls share the same Future
  final Map<_OpenKey, Future<List<TrophyHelpRequest>>> _openInFlight = {};

  // (Optional) My requests cache - left simple. Add TTL if you want.
  // final _CacheEntry<List<TrophyHelpRequest>>? _myCache;

  // ------------------------------
  // Public API
  // ------------------------------

  Future<TrophyHelpRequest> createRequest({
    required String gameId,
    required String gameTitle,
    required String achievementId,
    required String achievementName,
    required String platform,
    String? description,
    String? availability,
    String? platformUsername,
    DateTime? scheduledAt,
    int helpersNeeded = 1,
  }) async {
    final userId = _requireUserId();

    final row = await _supabase
        .from('trophy_help_requests')
        .insert({
          'user_id': userId, // Primary key (deprecated but still required)
          'profile_id': userId, // New column (profiles.id == auth.users.id)
          'game_id': gameId,
          'game_title': gameTitle,
          'achievement_id': achievementId,
          'achievement_name': achievementName,
          'platform': platform,
          'description': description,
          'availability': availability,
          'platform_username': platformUsername,
          'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
          'session_utc_offset_minutes': scheduledAt?.timeZoneOffset.inMinutes,
          'helpers_needed': helpersNeeded,
          'status': 'open',
        })
        .select()
        .single();

    // Dev verification: ensure profile_id was saved
    assert(
      row['profile_id'] != null,
      'MIGRATION ERROR: profile_id is null after insert',
    );

    // New data exists; open list is now stale
    _invalidateOpenCache();

    return TrophyHelpRequest.fromJson(row);
  }

  /// Get all open requests with optional filters.
  ///
  /// - TTL cached for 5 seconds by (platform, gameId)
  /// - In-flight de-duped so repeated calls won't hammer Supabase
  Future<List<TrophyHelpRequest>> getOpenRequests({
    String? platform,
    String? gameId,
  }) async {
    statusxpLog(
      '[SERVICE] getOpenRequests called with platform=$platform, gameId=$gameId at ${DateTime.now().millisecondsSinceEpoch}',
    );

    final key = _OpenKey(platform: platform, gameId: gameId);

    // 1) Return fresh cache if still valid
    final cached = _openCache[key];
    if (cached != null && !cached.isExpired(_openRequestsTtl)) {
      statusxpLog(
        '[SERVICE] Returning cached data (${cached.value.length} items)',
      );
      return cached.value;
    }

    // 2) If there is an in-flight request for the same key, await it
    final existingFuture = _openInFlight[key];
    if (existingFuture != null) {
      statusxpLog('[SERVICE] Returning in-flight future');
      return existingFuture;
    }

    statusxpLog('[SERVICE] Making NEW network request');

    // 3) Start a new request, store it in-flight, and clean up when done
    final future = _fetchOpenRequests(platform: platform, gameId: gameId)
        .then((results) {
          _openCache[key] = _CacheEntry(results, DateTime.now());
          return results;
        })
        .catchError((e) {
          // If fetch fails, return stale cache if any, otherwise empty list
          final stale = _openCache[key];
          return stale?.value ?? <TrophyHelpRequest>[];
        })
        .whenComplete(() {
          _openInFlight.remove(key);
        });

    _openInFlight[key] = future;
    return future;
  }

  Future<List<TrophyHelpRequest>> getMyRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return <TrophyHelpRequest>[];

    final rows = await _supabase
        .from('trophy_help_requests')
        .select()
        .eq('profile_id', user.id) // Use profile_id for filtering
        .order('created_at', ascending: false);

    return _mapList(rows, TrophyHelpRequest.fromJson);
  }

  Future<TrophyHelpRequest?> getRequest(String requestId) async {
    final row = await _supabase
        .from('trophy_help_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (row == null) return null;
    return TrophyHelpRequest.fromJson(row);
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await _supabase.rpc(
      'finish_coop_request',
      params: {'p_request_id': requestId, 'p_status': status},
    );

    // status changes affect open lists
    _invalidateOpenCache();
  }

  Future<void> deleteRequest(String requestId) async {
    await _supabase.from('trophy_help_requests').delete().eq('id', requestId);
    _invalidateOpenCache();
  }

  Future<TrophyHelpResponse> offerHelp({
    required String requestId,
    String? message,
  }) async {
    final userId = _requireUserId();

    final row = await _supabase
        .from('trophy_help_responses')
        .insert({
          'request_id': requestId,
          'helper_user_id': userId, // Deprecated but still required
          'helper_profile_id':
              userId, // New column (profiles.id == auth.users.id)
          'message': message,
          'status': 'pending',
        })
        .select()
        .single();

    // Dev verification: ensure helper_profile_id was saved
    assert(
      row['helper_profile_id'] != null,
      'MIGRATION ERROR: helper_profile_id is null after insert',
    );

    return TrophyHelpResponse.fromJson(row);
  }

  Future<List<TrophyHelpResponse>> getRequestResponses(String requestId) async {
    final rows = await _supabase
        .from('trophy_help_responses')
        .select('''
          *,
          helper_username:profiles!helper_profile_id(username, psn_online_id, xbox_gamertag, steam_id)
        ''')
        .eq('request_id', requestId)
        .order('created_at', ascending: false);

    // Extract profile data from nested object and flatten it
    final flattenedRows = rows.map((row) {
      final Map<String, dynamic> flatRow = Map.from(row);
      final helperProfile = row['helper_username'];
      if (helperProfile != null && helperProfile is Map) {
        flatRow['helper_username'] = helperProfile['username'] as String?;
        flatRow['helper_psn_online_id'] =
            helperProfile['psn_online_id'] as String?;
        flatRow['helper_xbox_gamertag'] =
            helperProfile['xbox_gamertag'] as String?;
        flatRow['helper_steam_id'] = helperProfile['steam_id'] as String?;
      }
      return flatRow;
    }).toList();

    return _mapList(flattenedRows, TrophyHelpResponse.fromJson);
  }

  Future<void> acceptHelper(String responseId) async {
    await _supabase.rpc(
      'accept_coop_offer',
      params: {'p_response_id': responseId},
    );
    _invalidateOpenCache();
  }

  Future<void> declineHelper(String responseId) async {
    await _supabase.rpc(
      'decline_coop_offer',
      params: {'p_response_id': responseId},
    );
  }

  Future<List<TrophyHelpRequest>> getRequestsIOfferedHelpOn() async {
    final userId = _requireUserId();

    final responseRows = await _supabase
        .from('trophy_help_responses')
        .select('request_id')
        .eq('helper_profile_id', userId); // Use helper_profile_id for filtering

    final ids = _mapList(responseRows, (r) => r['request_id'] as String);
    if (ids.isEmpty) return <TrophyHelpRequest>[];

    final requestRows = await _supabase
        .from('trophy_help_requests')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);

    return _mapList(requestRows, TrophyHelpRequest.fromJson);
  }

  // ------------------------------
  // Private helpers
  // ------------------------------

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in');
    }
    return userId;
  }

  Future<List<TrophyHelpRequest>> _fetchOpenRequests({
    String? platform,
    String? gameId,
  }) async {
    // Build query with optional filters
    var query = _supabase
        .from('trophy_help_requests')
        .select()
        .eq('status', 'open');

    if (platform != null) query = query.eq('platform', platform);
    if (gameId != null) query = query.eq('game_id', gameId);

    final rows = await query.order('created_at', ascending: false);
    return _mapList(rows, TrophyHelpRequest.fromJson);
  }

  void _invalidateOpenCache() {
    _openCache.clear();
    // optional: also cancel in-flight? usually not needed; let it finish.
  }

  static List<T> _mapList<T>(
    Object rows,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = rows as List;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}

// ------------------------------
// Cache models
// ------------------------------

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  const _CacheEntry(this.value, this.timestamp);

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;
}

class _OpenKey {
  final String? platform;
  final String? gameId;
  const _OpenKey({required this.platform, required this.gameId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OpenKey && other.platform == platform && other.gameId == gameId;

  @override
  int get hashCode => Object.hash(platform, gameId);
}
