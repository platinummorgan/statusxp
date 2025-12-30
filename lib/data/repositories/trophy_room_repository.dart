import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching Trophy Room data
/// 
/// Provides aggregated trophy statistics for showcase features like
/// rarest platinums, newest platinums, ultra-rare trophies, and recent unlocks.
class TrophyRoomRepository {
  final SupabaseClient _client;

  TrophyRoomRepository(this._client);

  /// Get all platinum trophies earned by the user with game details
  Future<List<Map<String, dynamic>>> getPlatinumTrophies(String userId) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select('''
            id,
            trophy_id,
            earned_at,
            trophies!inner(
              id,
              name,
              tier,
              rarity_global,
              game_title_id,
              icon_url,
              game_titles!inner(
                name,
                cover_url
              )
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      // Filter for platinum tier only
      final platinums = (response as List).where((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        return trophy['tier'] == 'platinum';
      }).toList();

      return platinums.map((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
        
        return {
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'cover_url': gameTitle['cover_url'],
          'rarity': (trophy['rarity_global'] as num?)?.toDouble() ?? 100.0,
          'earned_at': row['earned_at'],
          'icon_url': trophy['icon_url'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get ultra-rare trophies (earned and rarity < 2%)
  Future<List<Map<String, dynamic>>> getUltraRareTrophies(String userId, {int limit = 5}) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select('''
            id,
            trophy_id,
            earned_at,
            trophies!inner(
              id,
              name,
              tier,
              rarity_global,
              icon_url,
              game_title_id,
              game_titles!inner(
                name
              )
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      // Filter for ultra-rare (< 2%) and sort by rarity
      final ultraRare = (response as List).where((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final rarity = (trophy['rarity_global'] as num?)?.toDouble() ?? 100.0;
        return rarity < 2.0;
      }).toList();

      // Sort by rarity ascending (rarest first)
      ultraRare.sort((a, b) {
        final rarityA = (a['trophies']['rarity_global'] as num?)?.toDouble() ?? 100.0;
        final rarityB = (b['trophies']['rarity_global'] as num?)?.toDouble() ?? 100.0;
        return rarityA.compareTo(rarityB);
      });

      // Take only the limit
      final limited = ultraRare.take(limit).toList();

      return limited.map((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
        
        return {
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'rarity': (trophy['rarity_global'] as num?)?.toDouble() ?? 100.0,
          'earned_at': row['earned_at'],
          'icon_url': trophy['icon_url'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent trophies (last N earned across all games)
  Future<List<Map<String, dynamic>>> getRecentTrophies(String userId, {int limit = 10}) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select('''
            id,
            trophy_id,
            earned_at,
            trophies!inner(
              id,
              name,
              tier,
              icon_url,
              game_title_id,
              game_titles!inner(
                name
              )
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      return (response as List).map((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
        
        return {
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'earned_at': row['earned_at'],
          'icon_url': trophy['icon_url'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
