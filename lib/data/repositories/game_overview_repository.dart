import 'package:statusxp/domain/game_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameOverviewRepository {
  final SupabaseClient _client;

  GameOverviewRepository(this._client);

  Future<GameOverview?> getGame(GameRef gameRef, {String? userId}) async {
    final game = await _client
        .from('games')
        .select('name, cover_url, icon_url, metadata')
        .eq('platform_id', gameRef.platformId)
        .eq('platform_game_id', gameRef.platformGameId)
        .maybeSingle();

    if (game == null) return null;

    Map<String, dynamic>? progress;
    if (userId != null) {
      progress = await _client
          .from('user_progress')
          .select(
            'achievements_earned, total_achievements, completion_percentage, '
            'current_score, last_played_at',
          )
          .eq('user_id', userId)
          .eq('platform_id', gameRef.platformId)
          .eq('platform_game_id', gameRef.platformGameId)
          .maybeSingle();
    }

    DateTime? lastPlayedAt;
    final lastPlayed = progress?['last_played_at']?.toString();
    if (lastPlayed != null) lastPlayedAt = DateTime.tryParse(lastPlayed);

    return GameOverview(
      ref: gameRef,
      name: game['name']?.toString() ?? 'Unknown game',
      coverUrl: game['cover_url']?.toString(),
      iconUrl: game['icon_url']?.toString(),
      metadata: Map<String, dynamic>.from(game['metadata'] as Map? ?? const {}),
      achievementsEarned: _asInt(progress?['achievements_earned']),
      achievementsTotal: _asInt(progress?['total_achievements']),
      completionPercentage: _asDouble(progress?['completion_percentage']),
      currentScore: _asInt(progress?['current_score']),
      lastPlayedAt: lastPlayedAt,
      isOwned: progress != null,
    );
  }

  int _asInt(dynamic value) => value is num ? value.toInt() : 0;
  double _asDouble(dynamic value) => value is num ? value.toDouble() : 0;
}
