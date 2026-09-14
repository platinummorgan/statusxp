import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final basicLibraryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = ref.watch(currentUserIdProvider);
      if (user == null) return [];
      final client = ref.watch(supabaseClientProvider);
      final rows = <Map<String, dynamic>>[];
      while (true) {
        final page = await client
            .from('user_progress')
            .select(
              'platform_id,platform_game_id,achievements_earned,total_achievements,games(name)',
            )
            .eq('user_id', user)
            .order('platform_id', ascending: true)
            .order('platform_game_id', ascending: true)
            .range(rows.length, rows.length + 499);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      rows.sort(
        (a, b) => basicGameName(
          a,
        ).toLowerCase().compareTo(basicGameName(b).toLowerCase()),
      );
      return rows;
    });

String basicGameName(Map<String, dynamic> row) =>
    (row['games'] as Map?)?['name']?.toString() ?? 'Unknown game';

/// Lightweight recovery for a timed-out private library aggregate request.
class BasicLibrary extends ConsumerWidget {
  const BasicLibrary({super.key, required this.query, required this.onRetry});
  final String query;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(basicLibraryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text(
                'Detailed game stats took too long. Showing your synced library instead.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry detailed stats'),
              ),
            ],
          ),
        ),
        Expanded(
          child: library.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your library could not be loaded. Please try again.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(basicLibraryProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (rows) {
              final matches = rows
                  .where(
                    (row) => basicGameName(
                      row,
                    ).toLowerCase().contains(query.trim().toLowerCase()),
                  )
                  .toList();
              if (matches.isEmpty) {
                return const Center(child: Text('No games found.'));
              }
              return ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final row = matches[index];
                  final game = GameRef(
                    platformId: row['platform_id'] as int,
                    platformGameId: row['platform_game_id'].toString(),
                  );
                  return ListTile(
                    leading: const Icon(Icons.videogame_asset),
                    title: Text(basicGameName(row)),
                    subtitle: Text(
                      '${game.platform?.label ?? 'Unknown platform'} · ${row['achievements_earned'] ?? '—'}/${row['total_achievements'] ?? '—'} achievements synced',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: game.platform == null
                        ? null
                        : () => context.push(game.location),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
