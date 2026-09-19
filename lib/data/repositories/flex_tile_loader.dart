import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef FlexTileKey = ({
  String user,
  int platform,
  String game,
  String achievement,
});

/// Batches simultaneous tile requests without retaining data between loads.
class FlexTileLoader {
  FlexTileLoader(this.client);
  final SupabaseClient client;
  final _pending = <FlexTileKey, Completer<Map<String, dynamic>?>>{};
  final _inFlight = <FlexTileKey, Future<Map<String, dynamic>?>>{};

  Future<Map<String, dynamic>?> load(FlexTileKey key) {
    return _inFlight.putIfAbsent(key, () {
      final completer = Completer<Map<String, dynamic>?>();
      if (_pending.isEmpty) scheduleMicrotask(_flush);
      _pending[key] = completer;
      return completer.future.whenComplete(() {
        _inFlight.remove(key);
      });
    });
  }

  static String _quoted(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  static String _filter(FlexTileKey key, {bool gameOnly = false}) =>
      'and(platform_id.eq.${key.platform},platform_game_id.eq.${_quoted(key.game)}${gameOnly ? '' : ',platform_achievement_id.eq.${_quoted(key.achievement)}'})';

  Future<void> _flush() async {
    final pending = Map.of(_pending);
    _pending.clear();
    for (final user in pending.keys.map((k) => k.user).toSet()) {
      final keys = pending.keys.where((k) => k.user == user).toList();
      // Bound URL length and result size, even for large picker requests.
      for (var start = 0; start < keys.length; start += 20) {
        final batch = keys.skip(start).take(20).toList();
        try {
          final earned = await client
              .from('user_achievements')
              .select(
                'platform_id,platform_game_id,platform_achievement_id,earned_at',
              )
              .eq('user_id', user)
              .or(batch.map((k) => _filter(k)).join(','));
          final owned = <FlexTileKey, Map<String, dynamic>>{};
          for (final row in earned) {
            final key = (
              user: user,
              platform: row['platform_id'] as int,
              game: row['platform_game_id'] as String,
              achievement: row['platform_achievement_id'] as String,
            );
            if (batch.contains(key)) {
              owned[key] = row;
            }
          }
          if (owned.isEmpty) {
            for (final k in batch) {
              pending[k]!.complete(null);
            }
            continue;
          }
          final results = await Future.wait([
            client
                .from('achievements')
                .select(
                  'platform_id,platform_game_id,platform_achievement_id,name,icon_url,rarity_global',
                )
                .or(owned.keys.map((k) => _filter(k)).join(',')),
            client
                .from('games')
                .select('platform_id,platform_game_id,name,cover_url')
                .or(
                  owned.keys
                      .map((k) => _filter(k, gameOnly: true))
                      .toSet()
                      .join(','),
                ),
          ]);
          for (final k in batch) {
            final achievement = results[0]
                .where(
                  (r) =>
                      r['platform_id'] == k.platform &&
                      r['platform_game_id'] == k.game &&
                      r['platform_achievement_id'] == k.achievement,
                )
                .firstOrNull;
            final game = results[1]
                .where(
                  (r) =>
                      r['platform_id'] == k.platform &&
                      r['platform_game_id'] == k.game,
                )
                .firstOrNull;
            pending[k]!.complete(
              owned[k] == null || achievement == null
                  ? null
                  : {
                      ...owned[k]!,
                      'achievement_name': achievement['name'],
                      'achievement_icon_url': achievement['icon_url'],
                      'rarity_global': achievement['rarity_global'],
                      'game_name': game?['name'] ?? 'Unknown Game',
                      'game_cover_url': game?['cover_url'],
                    },
            );
          }
        } catch (error, stack) {
          for (final k in batch) {
            if (!pending[k]!.isCompleted) {
              pending[k]!.completeError(error, stack);
            }
          }
        }
      }
    }
  }
}
