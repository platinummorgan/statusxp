import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/steam_completion_award_card.dart';
import 'package:statusxp/ui/widgets/xbox_mythic_award_card.dart';

final gameCompletionAwardProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, GameRef>((ref, game) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null || ![4, 10, 11, 12].contains(game.platformId)) {
        return null;
      }
      return ref
          .watch(supabaseClientProvider)
          .from(
            game.platformId == 4
                ? 'steam_completion_awards'
                : 'xbox_mythic_awards',
          )
          .select('estimated_rarity,base_status_xp,rarity_source')
          .eq('user_id', userId)
          .eq('platform_id', game.platformId)
          .eq('platform_game_id', game.platformGameId)
          .maybeSingle();
    });

/// Native earned awards only; an overall progress percentage cannot grant one.
class GameCompletionAward extends ConsumerWidget {
  const GameCompletionAward({super.key, required this.game});
  final GameRef game;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(gameCompletionAwardProvider(game))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (award) {
          if (award == null) return const SizedBox.shrink();
          final points = (award['base_status_xp'] as num?)?.toDouble();
          final rarity = (award['estimated_rarity'] as num?)?.toDouble();
          return game.platformId == 4
              ? SteamCompletionAwardCard(
                  points: points,
                  estimatedRarity: rarity,
                  allAchievements:
                      award['rarity_source'] ==
                      'estimated_minimum_all_achievements',
                )
              : XboxMythicAwardCard(
                  points: points ?? 0.5,
                  estimatedRarity: rarity,
                );
        },
      );
}
