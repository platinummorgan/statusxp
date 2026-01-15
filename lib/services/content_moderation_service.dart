import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/config/supabase_config.dart';

class ContentModerationService {
  /// Check if content is safe using OpenAI Moderation API
  /// Returns true if content is safe, false if flagged
  Future<ModerationResult> moderateContent(String text) async {
    final supabase = Supabase.instance.client;
    final functionUrl = '${SupabaseConfig.supabaseUrl}/functions/v1/moderate-content';
    final accessToken = supabase.auth.currentSession?.accessToken;

    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'text': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Moderation check failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ModerationResult.fromJson(data);
  }
}

class ModerationResult {
  final bool isSafe;
  final String? reason;
  final Map<String, bool>? categories;

  ModerationResult({
    required this.isSafe,
    this.reason,
    this.categories,
  });

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      isSafe: json['is_safe'] as bool,
      reason: json['reason'] as String?,
      categories: json['categories'] != null
          ? Map<String, bool>.from(json['categories'] as Map)
          : null,
    );
  }
}
