import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:statusxp/config/supabase_config.dart';

class AchievementGuideService {
  /// Generate an achievement guide using Supabase Edge Function
  /// Returns a stream of text chunks as they're generated
  Stream<String> generateGuide({
    required String gameTitle,
    required String achievementName,
    required String achievementDescription,
    String? platform,
  }) async* {
    final supabase = Supabase.instance.client;
    final functionUrl = '${SupabaseConfig.supabaseUrl}/functions/v1/generate-achievement-guide';
    final accessToken = supabase.auth.currentSession?.accessToken;

    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    final request = http.Request('POST', Uri.parse(functionUrl))
      ..headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.supabaseAnonKey,
      })
      ..body = jsonEncode({
        'gameTitle': gameTitle,
        'achievementName': achievementName,
        'achievementDescription': achievementDescription,
        'platform': platform,
      });

    final response = await request.send();

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Failed to generate guide: $body');
    }

    // Parse SSE stream from OpenAI
    await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (chunk.isEmpty || chunk.startsWith(':')) continue;
      
      if (chunk.startsWith('data: ')) {
        final data = chunk.substring(6);
        if (data == '[DONE]') break;
        
        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta'];
          final content = delta?['content'];
          
          if (content != null && content is String) {
            yield content;
          }
        } catch (e) {
          // Skip malformed chunks
          continue;
        }
      }
    }
  }
}
