import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameCatalogTotals {
  const GameCatalogTotals(this.achievements, this.baseXp);
  final int achievements;
  final double? baseXp;
}

Future<GameCatalogTotals> loadGameCatalogTotals(
  SupabaseClient client,
  GameRef game,
) async {
  var count = 0;
  var xp = 0.0;
  var completeXp = true;
  const size = 500;
  while (true) {
    final rows = await client
        .from('achievements')
        .select('platform_achievement_id,base_status_xp')
        .eq('platform_id', game.platformId)
        .eq('platform_game_id', game.platformGameId)
        .order('platform_achievement_id', ascending: true)
        .range(count, count + size - 1);
    for (final row in rows) {
      final value = row['base_status_xp'];
      if (value is num && value.isFinite && value >= 0) {
        xp += value.toDouble();
      } else {
        completeXp = false;
      }
    }
    count += rows.length;
    if (rows.length < size) break;
  }
  return GameCatalogTotals(count, completeXp ? xp : null);
}

final gameCatalogTotalsProvider = FutureProvider.autoDispose
    .family<GameCatalogTotals, GameRef>(
      (ref, game) =>
          loadGameCatalogTotals(ref.watch(supabaseClientProvider), game),
    );

class GameCatalogSummary extends ConsumerWidget {
  const GameCatalogSummary({super.key, required this.game});
  final GameRef game;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    color: const Color(0xFF151A35),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: ref
          .watch(gameCatalogTotalsProvider(game))
          .when(
            loading: () => const Text('Loading achievement totals…'),
            error: (_, _) => Row(
              children: [
                const Expanded(child: Text('Game totals could not be loaded.')),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(gameCatalogTotalsProvider(game)),
                  child: const Text('Retry totals'),
                ),
              ],
            ),
            data: (totals) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${totals.achievements} ${[1, 2, 5, 9].contains(game.platformId) ? 'trophies' : 'achievements'} in the catalog',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totals.baseXp == null
                      ? 'Base StatusXP unavailable'
                      : '${totals.baseXp!.toStringAsFixed(0)} base StatusXP available',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Catalog totals include listed DLC. Base points are before scoring adjustments; these are not points you have earned.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
    ),
  );
}
