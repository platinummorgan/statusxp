import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Twitch account linking and subscription status
class TwitchService {
  final SupabaseClient _supabase;

  TwitchService(this._supabase);

  /// Link Twitch account using OAuth code
  /// 
  /// Returns result with subscription status
  Future<TwitchLinkResult> linkAccount(String code, String redirectUri) async {
    try {
      final response = await _supabase.functions.invoke(
        'twitch-link-account',
        body: {
          'code': code,
          'redirectUri': redirectUri,
        },
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Failed to link Twitch account';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;
      
      return TwitchLinkResult(
        success: data['success'] ?? false,
        twitchUserId: data['twitchUserId'],
        twitchUsername: data['twitchUsername'],
        twitchDisplayName: data['twitchDisplayName'],
        isSubscribed: data['isSubscribed'] ?? false,
      );
    } catch (e) {
      throw Exception('Failed to link Twitch account: $e');
    }
  }

  /// Check current subscription status
  /// 
  /// Returns subscription status for linked account
  Future<TwitchSubscriptionStatus> checkSubscription() async {
    try {
      final response = await _supabase.functions.invoke(
        'twitch-check-subscription',
      );

      if (response.status == 404) {
        return TwitchSubscriptionStatus(
          isLinked: false,
          isSubscribed: false,
        );
      }

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Failed to check subscription';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;
      
      return TwitchSubscriptionStatus(
        isLinked: data['isLinked'] ?? false,
        isSubscribed: data['isSubscribed'] ?? false,
        tier: data['tier'],
      );
    } catch (e) {
      throw Exception('Failed to check subscription: $e');
    }
  }

  /// Disconnect Twitch account
  /// 
  /// Removes twitch_user_id from profile
  Future<void> disconnect() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase
          .from('profiles')
          .update({'twitch_user_id': null})
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to disconnect Twitch: $e');
    }
  }
}

/// Result from linking Twitch account
class TwitchLinkResult {
  final bool success;
  final String? twitchUserId;
  final String? twitchUsername;
  final String? twitchDisplayName;
  final bool isSubscribed;

  TwitchLinkResult({
    required this.success,
    this.twitchUserId,
    this.twitchUsername,
    this.twitchDisplayName,
    required this.isSubscribed,
  });
}

/// Current Twitch subscription status
class TwitchSubscriptionStatus {
  final bool isLinked;
  final bool isSubscribed;
  final String? tier;

  TwitchSubscriptionStatus({
    required this.isLinked,
    required this.isSubscribed,
    this.tier,
  });
}
