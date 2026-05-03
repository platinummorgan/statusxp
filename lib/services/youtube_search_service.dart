import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

class YouTubeSearchService {
  final _supabase = Supabase.instance.client;

  /// Search YouTube for achievement guide videos via Supabase Edge Function
  /// Returns the first video URL found, or null if none found
  Future<String?> searchAchievementGuide({
    required String gameTitle,
    required String achievementName,
  }) async {
    statusxpLog(
      '🎬 YouTube search started - Game: "$gameTitle", Achievement: "$achievementName"',
    );

    // Build search query
    final query = '$gameTitle $achievementName trophy achievement guide';
    final fallbackSearchUrl = _buildSearchResultsUrl(query);
    statusxpLog('🔎 Searching YouTube for: "$query"');

    try {
      final response = await _supabase.functions.invoke(
        'youtube-search',
        body: {'query': query, 'maxResults': 1},
      );

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List?;

        if (items != null && items.isNotEmpty) {
          final first = items[0];
          String? videoId;

          if (first is Map<String, dynamic>) {
            final idNode = first['id'];
            if (idNode is Map<String, dynamic>) {
              videoId = idNode['videoId'] as String?;
            } else if (idNode is String && idNode.isNotEmpty) {
              // Some providers return a plain ID string.
              videoId = idNode;
            }
          }

          if (videoId != null && videoId.isNotEmpty) {
            final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
            statusxpLog('✅ Found YouTube video: $videoUrl');
            return videoUrl;
          }

          statusxpLog('⚠️ YouTube response had items but no usable videoId');
          return fallbackSearchUrl;
        } else {
          statusxpLog('⚠️ No YouTube videos found in search results');
          return fallbackSearchUrl;
        }
      } else {
        statusxpLog('❌ YouTube function error: ${response.status}');
        return fallbackSearchUrl;
      }
    } catch (e) {
      statusxpLog('❌ YouTube search exception: $e');
      return fallbackSearchUrl;
    }
  }

  String _buildSearchResultsUrl(String query) {
    final encoded = Uri.encodeQueryComponent(query);
    return 'https://www.youtube.com/results?search_query=$encoded';
  }
}
