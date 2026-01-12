import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';

class TrophyHelpService {
  TrophyHelpService(this._supabase);

  final SupabaseClient _supabase;

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
  }) async {
    final userId = _requireUserId();

    final row = await _supabase
        .from('trophy_help_requests')
        .insert({
          'user_id': userId,
          'game_id': gameId,
          'game_title': gameTitle,
          'achievement_id': achievementId,
          'achievement_name': achievementName,
          'platform': platform,
          'description': description,
          'availability': availability,
          'platform_username': platformUsername,
          'status': 'open',
        })
        .select()
        .single();

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
    final key = _OpenKey(platform: platform, gameId: gameId);

    // 1) Return fresh cache if still valid
    final cached = _openCache[key];
    if (cached != null && !cached.isExpired(_openRequestsTtl)) {
      return cached.value;
    }

    // 2) If there is an in-flight request for the same key, await it
    final existingFuture = _openInFlight[key];
    if (existingFuture != null) return existingFuture;

    // 3) Start a new request, store it in-flight, and clean up when done
    final future = _fetchOpenRequests(platform: platform, gameId: gameId)
        .then((results) {
          _openCache[key] = _CacheEntry(results, DateTime.now());
          return results;
        }).catchError((e) {
      // If fetch fails, return stale cache if any, otherwise empty list
      final stale = _openCache[key];
      return stale?.value ?? <TrophyHelpRequest>[];
    }).whenComplete(() {
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
        .eq('user_id', user.id)
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
    await _supabase
        .from('trophy_help_requests')
        .update({'status': status})
        .eq('id', requestId);

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
          'helper_user_id': userId,
          'message': message,
          'status': 'pending',
        })
        .select()
        .single();

    return TrophyHelpResponse.fromJson(row);
  }

  Future<List<TrophyHelpResponse>> getRequestResponses(String requestId) async {
    final rows = await _supabase
        .from('trophy_help_responses')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: false);

    return _mapList(rows, TrophyHelpResponse.fromJson);
  }

  Future<void> acceptHelper(String responseId) async {
    await _supabase
        .from('trophy_help_responses')
        .update({'status': 'accepted'})
        .eq('id', responseId);
  }

  Future<void> declineHelper(String responseId) async {
    await _supabase
        .from('trophy_help_responses')
        .update({'status': 'declined'})
        .eq('id', responseId);
  }

  Future<List<TrophyHelpRequest>> getRequestsIOfferedHelpOn() async {
    final userId = _requireUserId();

    final responseRows = await _supabase
        .from('trophy_help_responses')
        .select('request_id')
        .eq('helper_user_id', userId);

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
      other is _OpenKey &&
          other.platform == platform &&
          other.gameId == gameId;

  @override
  int get hashCode => Object.hash(platform, gameId);
}
