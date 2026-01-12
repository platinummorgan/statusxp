import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy_help_request.dart';

class TrophyHelpService {
  final SupabaseClient _supabase;

  TrophyHelpService(this._supabase);

  /// Create a new help request
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in to create a request');
    }

    final response = await _supabase.from('trophy_help_requests').insert({
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
    }).select().single();

    return TrophyHelpRequest.fromJson(response);
  }

  /// Get all open requests with optional filters
  Future<List<TrophyHelpRequest>> getOpenRequests({
    String? platform,
    String? gameId,
  }) async {
    try {
      final queryBuilder = _supabase
          .from('trophy_help_requests')
          .select()
          .eq('status', 'open');

      // Apply filters
      var filteredQuery = queryBuilder;
      if (platform != null) {
        filteredQuery = filteredQuery.eq('platform', platform);
      }
      if (gameId != null) {
        filteredQuery = filteredQuery.eq('game_id', gameId);
      }

      final response = await filteredQuery.order('created_at', ascending: false);
      return (response as List)
          .map((json) => TrophyHelpRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching open requests: $e');
      // Return empty list instead of throwing to avoid breaking UI
      return [];
    }
  }

  /// Get user's own requests
  Future<List<TrophyHelpRequest>> getMyRequests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('User not logged in, returning empty requests');
        return [];
      }

      final response = await _supabase
          .from('trophy_help_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => TrophyHelpRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching my requests: $e');
      return [];
    }
  }

  /// Get a specific request by ID
  Future<TrophyHelpRequest?> getRequest(String requestId) async {
    final response = await _supabase
        .from('trophy_help_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (response == null) return null;
    return TrophyHelpRequest.fromJson(response);
  }

  /// Update request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    await _supabase
        .from('trophy_help_requests')
        .update({'status': status})
        .eq('id', requestId);
  }

  /// Delete a request
  Future<void> deleteRequest(String requestId) async {
    await _supabase.from('trophy_help_requests').delete().eq('id', requestId);
  }

  /// Offer help on a request
  Future<TrophyHelpResponse> offerHelp({
    required String requestId,
    String? message,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in to offer help');
    }

    final response = await _supabase.from('trophy_help_responses').insert({
      'request_id': requestId,
      'helper_user_id': userId,
      'message': message,
      'status': 'pending',
    }).select().single();

    return TrophyHelpResponse.fromJson(response);
  }

  /// Get all responses for a request
  Future<List<TrophyHelpResponse>> getRequestResponses(String requestId) async {
    final response = await _supabase
        .from('trophy_help_responses')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => TrophyHelpResponse.fromJson(json))
        .toList();
  }

  /// Accept a helper's offer
  Future<void> acceptHelper(String responseId) async {
    await _supabase
        .from('trophy_help_responses')
        .update({'status': 'accepted'})
        .eq('id', responseId);
  }

  /// Decline a helper's offer
  Future<void> declineHelper(String responseId) async {
    await _supabase
        .from('trophy_help_responses')
        .update({'status': 'declined'})
        .eq('id', responseId);
  }

  /// Get requests where user has offered help
  Future<List<TrophyHelpRequest>> getRequestsIOfferedHelpOn() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in');
    }

    // Get request IDs where user has responded
    final responses = await _supabase
        .from('trophy_help_responses')
        .select('request_id')
        .eq('helper_user_id', userId);

    if ((responses as List).isEmpty) {
      return [];
    }

    final requestIds = responses.map((r) => r['request_id'] as String).toList();

    // Get the actual requests
    final requests = await _supabase
        .from('trophy_help_requests')
        .select()
        .inFilter('id', requestIds)
        .order('created_at', ascending: false);

    return (requests as List)
        .map((json) => TrophyHelpRequest.fromJson(json))
        .toList();
  }
}
