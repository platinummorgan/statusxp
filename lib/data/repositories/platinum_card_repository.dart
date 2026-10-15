import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlatinumCardRepository {
  PlatinumCardRepository(this.client);
  final SupabaseClient client;
  Future<PlatinumCardData?> get(AchievementRef ref) async {
    final data = await client.rpc(
      'get_my_platinum_card',
      params: {
        'p_platform': ref.gameRef.platformId,
        'p_game': ref.gameRef.platformGameId,
        'p_achievement': ref.platformAchievementId,
      },
    );
    return data == null
        ? null
        : PlatinumCardData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<PlatinumCardData>> list({int offset = 0}) async {
    final data = await client.rpc(
      'get_my_platinum_cards',
      params: {'p_offset': offset, 'p_limit': 40},
    );
    return (data as List)
        .map(
          (x) => PlatinumCardData.fromJson(Map<String, dynamic>.from(x as Map)),
        )
        .toList();
  }

  Future<PlatinumCelebration?> discover() async {
    final data = await client.rpc('discover_my_platinum_celebration');
    return data == null
        ? null
        : PlatinumCelebration.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> acknowledge(String id) async {
    await client.rpc(
      'acknowledge_my_platinum_celebration',
      params: {'p_id': id},
    );
  }
}
