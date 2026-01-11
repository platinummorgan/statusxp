import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';

/// Repository for managing display case items
/// 
/// Handles CRUD operations for user's custom trophy display
class DisplayCaseRepository {
  final SupabaseClient _client;

  DisplayCaseRepository(this._client);

  /// Get all display items for a user
  Future<List<DisplayCaseItem>> getDisplayItems(String userId) async {
    try {
      final response = await _client
          .from('display_case_items')
          .select('''
            id,
            user_id,
            trophy_id,
            display_type,
            shelf_number,
            position_in_shelf,
            trophies!inner(
              id,
              name,
              tier,
              rarity_global,
              icon_url,
              game_title_id,
              game_titles!inner(
                name,
                cover_url,
                proxied_cover_url
              )
            )
          ''')
          .eq('user_id', userId)
          .order('shelf_number')
          .order('position_in_shelf');

      return (response as List).map((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
        
        return DisplayCaseItem.fromMap({
          'id': row['id'],
          'user_id': row['user_id'],
          'trophy_id': row['trophy_id'],
          'display_type': row['display_type'],
          'shelf_number': row['shelf_number'],
          'position_in_shelf': row['position_in_shelf'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'rarity': trophy['rarity_global'],
          'icon_url': trophy['icon_url'],
          'game_image_url': gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'],
        });
      }).toList();
    } catch (e) {
      return [];
    }
  }  /// Add a new trophy to the display case
  /// If the position is already occupied, it will be replaced
  Future<DisplayCaseItem?> addItem({
    required String userId,
    required int trophyId,
    required DisplayItemType displayType,
    required int shelfNumber,
    required int positionInShelf,
  }) async {
    try {
      // First, delete whatever is at this position (if anything)
      await _client
          .from('display_case_items')
          .delete()
          .eq('user_id', userId)
          .eq('shelf_number', shelfNumber)
          .eq('position_in_shelf', positionInShelf);
      
      // Now insert the new trophy
      final response = await _client
          .from('display_case_items')
          .insert({
            'user_id': userId,
            'trophy_id': trophyId,
            'display_type': displayType.name,
            'shelf_number': shelfNumber,
            'position_in_shelf': positionInShelf,
          })
          .select('''
            id,
            user_id,
            trophy_id,
            display_type,
            shelf_number,
            position_in_shelf,
            trophies!inner(
              name,
              tier,
              rarity_global,
              icon_url,
              game_titles!inner(
                name,
                cover_url,
                proxied_cover_url
              )
            )
          ''')
          .single();

      final trophy = response['trophies'] as Map<String, dynamic>;
      final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
      
      return DisplayCaseItem.fromMap({
        'id': response['id'],
        'user_id': response['user_id'],
        'trophy_id': response['trophy_id'],
        'display_type': response['display_type'],
        'shelf_number': response['shelf_number'],
        'position_in_shelf': response['position_in_shelf'],
        'trophy_name': trophy['name'],
        'game_name': gameTitle['name'],
        'tier': trophy['tier'],
        'rarity': trophy['rarity_global'],
        'icon_url': trophy['icon_url'],
        'game_image_url': gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'],
      });
    } catch (e) {
      return null;
    }
  }

  /// Update item position (for drag & drop)
  Future<bool> updateItemPosition({
    required String itemId,
    required int newShelfNumber,
    required int newPositionInShelf,
  }) async {
    try {
      await _client
          .from('display_case_items')
          .update({
            'shelf_number': newShelfNumber,
            'position_in_shelf': newPositionInShelf,
          })
          .eq('id', itemId);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Swap positions of two items
  Future<bool> swapItems(DisplayCaseItem item1, DisplayCaseItem item2) async {
    try {
      // Use a 3-step process to avoid unique constraint violation:
      // First delete item1, then move item2, then re-insert item1 at item2's position
      
      // Store item1's data
      final item1Data = {
        'user_id': item1.userId,
        'trophy_id': item1.trophyId,
        'display_type': item1.displayType.name,
        'shelf_number': item2.shelfNumber,
        'position_in_shelf': item2.positionInShelf,
      };
      
      // Step 1: Delete item1
      await _client
          .from('display_case_items')
          .delete()
          .eq('id', item1.id);
      
      // Step 2: Move item2 to item1's original position
      await _client
          .from('display_case_items')
          .update({
            'shelf_number': item1.shelfNumber,
            'position_in_shelf': item1.positionInShelf,
          })
          .eq('id', item2.id);
      
      // Step 3: Re-insert item1 at item2's original position
      await _client
          .from('display_case_items')
          .insert({
            'id': item1.id,
            ...item1Data,
          });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove an item from the display
  Future<bool> removeItem(String itemId) async {
    try {
      await _client
          .from('display_case_items')
          .delete()
          .eq('id', itemId);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a position is occupied
  Future<bool> isPositionOccupied({
    required String userId,
    required int shelfNumber,
    required int positionInShelf,
  }) async {
    try {
      final response = await _client
          .from('display_case_items')
          .select('id')
          .eq('user_id', userId)
          .eq('shelf_number', shelfNumber)
          .eq('position_in_shelf', positionInShelf)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get all available trophies for a user (for adding to display)
  Future<List<Map<String, dynamic>>> getAvailableTrophies(String userId) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select('''
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
                name,
                cover_url,
                proxied_cover_url
              )
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return (response as List).map((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final gameTitle = trophy['game_titles'] as Map<String, dynamic>;
        
        return {
          'trophy_id': row['trophy_id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'rarity': trophy['rarity_global'],
          'icon_url': trophy['icon_url'],
          'game_image_url': gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'],
          'earned_at': row['earned_at'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the rarest trophy of a specific tier for a user
  Future<DisplayCaseItem?> getRarestTrophyOfTier(String userId, String tier) async {
    try {
      // First get all user's trophy IDs for this tier
      final userTrophyIds = await _client
          .from('user_trophies')
          .select('trophy_id')
          .eq('user_id', userId);
      
      if (userTrophyIds.isEmpty) return null;
      
      final trophyIds = (userTrophyIds as List).map((row) => row['trophy_id'] as int).toList();
      
      // Now get the rarest trophy from those IDs
      // TODO: Future enhancement - calculate hybrid rarity combining PSN global + app-specific rarity
      final response = await _client
          .from('trophies')
          .select('''
            id,
            name,
            tier,
            rarity_global,
            icon_url,
            game_title_id,
            game_titles!inner(
              name,
              cover_url,
              proxied_cover_url
            )
          ''')
          .eq('tier', tier)
          .inFilter('id', trophyIds)
          .not('rarity_global', 'is', null)
          .order('rarity_global', ascending: true)
          .order('id', ascending: true) // Secondary sort for consistency when rarities match
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final gameTitle = response['game_titles'] as Map<String, dynamic>;
      
      return DisplayCaseItem.fromMap({
        'id': '',
        'user_id': userId,
        'trophy_id': response['id'],
        'display_type': 'trophy_icon',
        'shelf_number': -1,
        'position_in_shelf': -1,
        'trophy_name': response['name'],
        'game_name': gameTitle['name'],
        'tier': response['tier'],
        'rarity': response['rarity_global'],
        'icon_url': response['icon_url'],
        'game_image_url': gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'],
      });
    } catch (e) {
      return null;
    }
  }
}
