import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/trophy.dart';

/// Supabase-based implementation for fetching trophies
class SupabaseTrophyRepository {
  final SupabaseClient _client;

  SupabaseTrophyRepository(this._client);

  /// Get all trophies for a game with earned status for the user
  Future<List<Trophy>> getTrophiesForGame(String userId, int gameTitleId) async {
    try {
      // First, get all trophies for the game
      final trophiesResponse = await _client
          .from('trophies')
          .select('id, name, description, tier, icon_url, rarity_global, hidden, sort_order')
          .eq('game_title_id', gameTitleId)
          .order('sort_order')
          .range(0, 999); // Use range instead of limit

      // Get trophy IDs
      final trophyIds = (trophiesResponse as List).map((t) => t['id']).toList();

      // Second, get earned status for these trophies
      final earnedResponse = await _client
          .from('user_trophies')
          .select('trophy_id, earned_at')
          .eq('user_id', userId)
          .inFilter('trophy_id', trophyIds);

      // Create a map of trophy_id -> earned_at
      final earnedMap = <int, String>{};
      for (final row in (earnedResponse as List)) {
        earnedMap[row['trophy_id'] as int] = row['earned_at'] as String;
      }

      return (trophiesResponse).map((row) {
        final earnedAt = earnedMap[row['id'] as int];

        return Trophy(
          id: row['id'].toString(),
          name: row['name'] as String,
          description: row['description'] as String?,
          tier: row['tier'] as String,
          iconUrl: row['icon_url'] as String?,
          rarityGlobal: (row['rarity_global'] as num?)?.toDouble(),
          hidden: row['hidden'] as bool? ?? false,
          earned: earnedAt != null,
          earnedAt: earnedAt != null ? DateTime.parse(earnedAt) : null,
        );
      }).toList();
    } catch (e) {
      print('ERROR fetching trophies: $e');
      rethrow;
    }
  }
}
