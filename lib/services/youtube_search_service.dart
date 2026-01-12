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
    print('🎬 YouTube search started - Game: "$gameTitle", Achievement: "$achievementName"');
    
    // Try dotenv first (works on mobile), fallback to compile-time constant (web)
    String? apiKey = dotenv.env['YOUTUBE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = const String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
    }
    
    print('🔑 YouTube API key: ${apiKey.isEmpty ? "EMPTY/MISSING" : "Found (${apiKey.length} chars)"}');
    
    if (apiKey.isEmpty) {
      print('❌ YouTube API key is missing or empty - search aborted');
      return null;
    }
    
    print('🔎 Searching YouTube for: "$gameTitle $achievementName"');

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
          final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
          print('✅ Found YouTube video: $videoUrl');
          return videoUrl;
        } else {
          print('⚠️ No YouTube videos found in search results');
        }
      } else {
        print('❌ YouTube API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ YouTube search exception: $e');
      return null;
    }

    return null;
  }
}
