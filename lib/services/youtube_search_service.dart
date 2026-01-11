import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class YouTubeSearchService {
  static const _baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  /// Search YouTube for achievement guide videos
  /// Returns the first video URL found, or null if none found
  Future<String?> searchAchievementGuide({
    required String gameTitle,
    required String achievementName,
  }) async {
    String? apiKey;
    if (kIsWeb) {
      // On web, API key would come from Vercel environment variables
      apiKey = const String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
    } else {
      apiKey = dotenv.env['YOUTUBE_API_KEY'];
    }
    
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    // Build search query
    final query = '$gameTitle $achievementName trophy achievement guide';
    
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'key': apiKey,
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': '1',
        'order': 'relevance',
        'videoEmbeddable': 'true',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List?;
        
        if (items != null && items.isNotEmpty) {
          final videoId = items[0]['id']['videoId'];
          return 'https://www.youtube.com/watch?v=$videoId';
        }
      } else {
      }
    } catch (e) {
      return null;
    }

    return null;
  }
}
