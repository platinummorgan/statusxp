import 'dart:convert';
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
    final apiKey = dotenv.env['YOUTUBE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('YOUTUBE_API_KEY not found in .env file');
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
        print('YouTube API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error searching YouTube: $e');
      return null;
    }

    return null;
  }
}
