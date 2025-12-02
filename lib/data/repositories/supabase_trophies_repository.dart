import 'package:supabase_flutter/supabase_flutter.dart';

/// Trophy model for Supabase data.
class Trophy {
  final int id;
  final int gameTitleId;
  final String name;
  final String description;
  final String tier; // bronze, silver, gold, platinum
  final double? rarityGlobal;

  const Trophy({
    required this.id,
    required this.gameTitleId,
    required this.name,
    required this.description,
    required this.tier,
    this.rarityGlobal,
  });

  factory Trophy.fromJson(Map<String, dynamic> json) {
    return Trophy(
      id: json['id'] as int,
      gameTitleId: json['game_title_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      tier: json['tier'] as String,
      rarityGlobal: (json['rarity_global'] as num?)?.toDouble(),
    );
  }
}

/// User trophy unlock record.
class UserTrophy {
  final int id;
  final String userId;
  final int trophyId;
  final DateTime earnedAt;

  const UserTrophy({
    required this.id,
    required this.userId,
    required this.trophyId,
    required this.earnedAt,
  });

  factory UserTrophy.fromJson(Map<String, dynamic> json) {
    return UserTrophy(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      trophyId: json['trophy_id'] as int,
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }
}

/// Supabase-based implementation for trophy data.
/// 
/// Fetches trophies from the `trophies` table and manages user trophy unlocks
/// in the `user_trophies` table.
class SupabaseTrophiesRepository {
  final SupabaseClient _client;
  
  SupabaseTrophiesRepository(this._client);

  /// Get all trophies for a specific game title.
  Future<List<Trophy>> getTrophiesForGame(int gameTitleId) async {
    try {
      final response = await _client
          .from('trophies')
          .select()
          .eq('game_title_id', gameTitleId);

      return (response as List)
          .map((json) => Trophy.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all user trophy unlocks for a specific user.
  Future<List<UserTrophy>> getUserTrophies(String userId) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((json) => UserTrophy.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user trophies for a specific game.
  Future<List<UserTrophy>> getUserTrophiesForGame(String userId, int gameTitleId) async {
    try {
      final response = await _client
          .from('user_trophies')
          .select('''
            id,
            user_id,
            trophy_id,
            earned_at,
            trophies!inner(game_title_id)
          ''')
          .eq('user_id', userId);

      // Filter by game_title_id
      final filtered = (response as List).where((row) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        return trophy['game_title_id'] == gameTitleId;
      }).toList();

      return filtered
          .map((json) => UserTrophy.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Insert a new trophy unlock for a user.
  Future<void> insertUserTrophy(String userId, int trophyId) async {
    try {
      await _client.from('user_trophies').insert({
        'user_id': userId,
        'trophy_id': trophyId,
        'earned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Update the earned timestamp for an existing user trophy.
  Future<void> updateUserTrophy(int userTrophyId, DateTime earnedAt) async {
    try {
      await _client.from('user_trophies').update({
        'earned_at': earnedAt.toIso8601String(),
      }).eq('id', userTrophyId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a user trophy unlock (un-earn a trophy).
  Future<void> deleteUserTrophy(int userTrophyId) async {
    try {
      await _client
          .from('user_trophies')
          .delete()
          .eq('id', userTrophyId);
    } catch (e) {
      rethrow;
    }
  }
}
