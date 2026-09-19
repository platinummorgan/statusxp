import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:statusxp/domain/achievement_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementOverviewRepository {
  final SupabaseClient _client;
  AchievementOverviewRepository(this._client);

  Future<AchievementOverview?> getAchievement(
    AchievementRef ref, {
    String? userId,
  }) async {
    final achievement = await _client
        .from('achievements')
        .select(
          'name, description, icon_url, proxied_icon_url, rarity_global, '
          'base_status_xp, rarity_multiplier, score_value, is_platinum, metadata',
        )
        .eq('platform_id', ref.gameRef.platformId)
        .eq('platform_game_id', ref.gameRef.platformGameId)
        .eq('platform_achievement_id', ref.platformAchievementId)
        .maybeSingle();
    if (achievement == null) return null;

    final game = await _client
        .from('games')
        .select('name, cover_url')
        .eq('platform_id', ref.gameRef.platformId)
        .eq('platform_game_id', ref.gameRef.platformGameId)
        .maybeSingle();

    Map<String, dynamic>? earned;
    if (userId != null) {
      earned = await _client
          .from('user_achievements')
          .select('earned_at')
          .eq('user_id', userId)
          .eq('platform_id', ref.gameRef.platformId)
          .eq('platform_game_id', ref.gameRef.platformGameId)
          .eq('platform_achievement_id', ref.platformAchievementId)
          .maybeSingle();
    }

    final metadata = Map<String, dynamic>.from(
      achievement['metadata'] as Map? ?? const {},
    );
    final baseXP = (achievement['base_status_xp'] as num?)?.toDouble() ?? 0;
    final multiplier =
        (achievement['rarity_multiplier'] as num?)?.toDouble() ?? 1;
    final earnedAt = DateTime.tryParse(earned?['earned_at']?.toString() ?? '');
    final rawIcon = achievement['icon_url']?.toString();
    final proxiedIcon = achievement['proxied_icon_url']?.toString();

    return AchievementOverview(
      ref: ref,
      name: achievement['name']?.toString() ?? 'Unknown achievement',
      gameName: game?['name']?.toString() ?? 'Unknown game',
      gameCoverUrl: game?['cover_url']?.toString(),
      description: achievement['description']?.toString(),
      iconUrl: kIsWeb && ref.gameRef.platformId != 4
          ? (proxiedIcon ?? rawIcon)
          : rawIcon,
      rarityGlobal: (achievement['rarity_global'] as num?)?.toDouble(),
      statusXP: baseXP * multiplier,
      scoreValue: (achievement['score_value'] as num?)?.toInt() ?? 0,
      isPlatinum: achievement['is_platinum'] as bool? ?? false,
      isHidden:
          _readBool(metadata['hidden']) ||
          _readBool(metadata['psn_hidden']) ||
          _readBool(metadata['steam_hidden']) ||
          _readBool(metadata['xbox_is_secret']),
      earnedAt: earnedAt,
      metadata: metadata,
    );
  }

  bool _readBool(dynamic value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true';
}
