import 'package:supabase_flutter/supabase_flutter.dart';

class SteamService {
  final SupabaseClient _client;

  SteamService(this._client);

  Future<SteamLinkStartResult> startLink({required String returnTo}) async {
    final response = await _client.functions.invoke(
      'steam-start-link',
      body: {'returnTo': returnTo},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Failed to start Steam link';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return SteamLinkStartResult(
      authUrl: data['authUrl'] as String,
      returnTo: data['returnTo'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  Future<SteamLinkCompleteResult> completeLink({
    required String callbackUrl,
  }) async {
    final response = await _client.functions.invoke(
      'steam-link-account',
      body: {'callbackUrl': callbackUrl},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Failed to link Steam account';
      final message = response.data?['message'];
      throw Exception(message ?? error);
    }

    final data = response.data as Map<String, dynamic>;
    return SteamLinkCompleteResult(
      success: data['success'] as bool? ?? false,
      steamId: data['steamId'] as String,
      steamDisplayName: data['steamDisplayName'] as String?,
    );
  }
}

class SteamLinkStartResult {
  final String authUrl;
  final String returnTo;
  final DateTime expiresAt;

  SteamLinkStartResult({
    required this.authUrl,
    required this.returnTo,
    required this.expiresAt,
  });
}

class SteamLinkCompleteResult {
  final bool success;
  final String steamId;
  final String? steamDisplayName;

  SteamLinkCompleteResult({
    required this.success,
    required this.steamId,
    this.steamDisplayName,
  });
}
