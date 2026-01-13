import 'package:supabase_flutter/supabase_flutter.dart';

class YouTubeSearchService {
  final _supabase = Supabase.instance.client;

  /// Search YouTube for achievement guide videos via Supabase Edge Function
  /// Returns the first video URL found, or null if none found
  Future<String?> searchAchievementGuide({
    required String gameTitle,
    required String achievementName,
  }) async {
    print('🎬 YouTube search started - Game: "$gameTitle", Achievement: "$achievementName"');
    
    // Build search query
    final query = '$gameTitle $achievementName trophy achievement guide';
    print('🔎 Searching YouTube for: "$query"');
    
    try {
      final response = await _supabase.functions.invoke(
        'youtube-search',
        body: {
          'query': query,
          'maxResults': 1,
        },
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
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
        print('❌ YouTube function error: ${response.status}');
      }
    } catch (e) {
      print('❌ YouTube search exception: $e');
      return null;
    }

    return null;
  }
}
