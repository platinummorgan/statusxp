import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:statusxp/config/supabase_config.dart';

class GuideCreditsUnavailable implements Exception {
  @override
  String toString() => 'No AI credits available.';
}

class AchievementGuideService {
  AchievementGuideService({
    http.Client? client,
    String? Function()? accessToken,
    String? Function()? userId,
  }) : _client = client,
       _accessToken =
           accessToken ??
           (() => Supabase.instance.client.auth.currentSession?.accessToken),
       _userId =
           userId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final http.Client? _client;
  final String? Function() _accessToken;
  final String? Function() _userId;

  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Server settles the credit and saves a replayable result before delivery.
  Stream<String> generateGuide({
    required String gameTitle,
    required String achievementName,
    required String achievementDescription,
    String? platform,
  }) async* {
    final token = _accessToken();
    final user = _userId();
    if (token == null || user == null) {
      throw Exception('Sign in to generate a guide.');
    }
    final content = {
      'gameTitle': gameTitle,
      'achievementName': achievementName,
      'achievementDescription': achievementDescription,
      'platform': platform,
    };
    final identity = jsonEncode([user, content]);
    final preferences = await SharedPreferences.getInstance();
    final key = 'ai_guide_request_${sha256.convert(utf8.encode(identity))}';
    // A deterministic first ID also deduplicates first requests from separate
    // tabs/devices. Subsequent attempts are persisted after a confirmed refund.
    final digest = sha256.convert(utf8.encode(identity)).toString();
    final firstId =
        '${digest.substring(0, 8)}-${digest.substring(8, 12)}-4${digest.substring(13, 16)}-8${digest.substring(17, 20)}-${digest.substring(20, 32)}';
    final requestId = preferences.getString(key) ?? firstId;
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              '${SupabaseConfig.supabaseUrl}/functions/v1/generate-achievement-guide',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.supabaseAnonKey,
            },
            body: jsonEncode({...content, 'requestId': requestId}),
          )
          .timeout(const Duration(seconds: 60));
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        if (response.statusCode == 402) throw GuideCreditsUnavailable();
        // A new attempt is safe only after the server confirms release.
        if ((response.statusCode == 422 ||
                response.statusCode == 429 ||
                response.statusCode == 503) &&
            body['code'] == 'released') {
          await preferences.setString(key, _newRequestId());
        }
        throw Exception(
          body['error'] is String
              ? body['error']
              : 'Guide unavailable. Try again.',
        );
      }
      if (_userId() != user) {
        throw Exception('Your account changed. Please reopen the guide.');
      }
      final guide = body['guide'];
      if (guide is! String || guide.trim().isEmpty) {
        throw Exception('Guide unavailable. Try again.');
      }
      yield guide;
    } finally {
      if (_client == null) client.close();
    }
  }
}
