import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';

final gameAchievementListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, GameRef>((ref, game) async {
      final userId = ref.watch(currentUserIdProvider);
      final client = ref.watch(supabaseClientProvider);
      Future<List<Map<String, dynamic>>> readRows(String table) async {
        final rows = <Map<String, dynamic>>[];
        while (true) {
          var query = client
              .from(table)
              .select(
                table == 'achievements'
                    ? 'platform_achievement_id,name,description,metadata,base_status_xp'
                    : 'platform_achievement_id',
              );
          query = query
              .eq('platform_id', game.platformId)
              .eq('platform_game_id', game.platformGameId);
          if (table == 'user_achievements') {
            query = query.eq('user_id', userId!);
          }
          final page = await query
              .order('platform_achievement_id')
              .range(rows.length, rows.length + 499);
          rows.addAll(page);
          if (page.length < 500) return rows;
        }
      }

      final results = await Future.wait([
        readRows('achievements'),
        if (userId != null) readRows('user_achievements'),
      ]);
      final earned = results.length > 1
          ? results[1].map((row) => row['platform_achievement_id']).toSet()
          : <dynamic>{};
      return results.first
          .map(
            (row) => <String, dynamic>{
              ...row,
              'earned': earned.contains(row['platform_achievement_id']),
            },
          )
          .toList();
    });

/// Inline catalog with independent loading and state retained while collapsed.
class GameAchievementSection extends ConsumerStatefulWidget {
  const GameAchievementSection({super.key, required this.game});
  final GameRef game;

  @override
  ConsumerState<GameAchievementSection> createState() => _SectionState();
}

class _SectionState extends ConsumerState<GameAchievementSection> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _expanded = true;
  bool _reveal = false;
  String _query = '';
  String _filter = 'All';
  int _page = 0;
  static const _pageSize = 20;

  bool _hidden(Map<String, dynamic> row) {
    final metadata = row['metadata'] as Map? ?? {};
    return row['earned'] != true &&
        !_reveal &&
        ['hidden', 'psn_hidden', 'steam_hidden', 'xbox_is_secret'].any(
          (key) => [
            'true',
            '1',
            'yes',
            'hidden',
          ].contains(metadata[key].toString().toLowerCase()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gameAchievementListProvider(widget.game));
    final signedIn = ref.watch(currentUserIdProvider) != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: _expanded,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: const Text('Achievements'),
              ),
            ),
            if (_expanded) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search achievements',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {
                  _query = value.trim().toLowerCase();
                  _page = 0;
                }),
                controller: _search,
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final filter in [
                    'All',
                    if (signedIn) ...['Earned', 'Unearned'],
                  ])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() {
                        _filter = filter;
                        _page = 0;
                      }),
                    ),
                  FilterChip(
                    label: const Text('Reveal hidden'),
                    selected: _reveal,
                    onSelected: (value) => setState(() {
                      _reveal = value;
                      _page = 0;
                    }),
                  ),
                ],
              ),
              data.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Column(
                  children: [
                    const Text('Unable to load achievements.'),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        gameAchievementListProvider(widget.game),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
                data: (rows) {
                  final filtered = rows.where((row) {
                    if (signedIn &&
                        _filter == 'Earned' &&
                        row['earned'] != true) {
                      return false;
                    }
                    if (signedIn &&
                        _filter == 'Unearned' &&
                        row['earned'] == true) {
                      return false;
                    }
                    final text = _hidden(row)
                        ? 'hidden achievement'
                        : '${row['name']} ${row['description']}';
                    return text.toLowerCase().contains(_query);
                  }).toList();
                  final pages = (filtered.length / _pageSize).ceil();
                  final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
                  return Column(
                    children: [
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No achievements match.'),
                        ),
                      for (final row
                          in filtered.skip(page * _pageSize).take(_pageSize))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            row['earned'] == true
                                ? Icons.check_circle
                                : Icons.emoji_events_outlined,
                          ),
                          title: Text(
                            _hidden(row)
                                ? 'Hidden achievement'
                                : row['name'] as String? ?? 'Achievement',
                          ),
                          subtitle: Text(
                            _hidden(row)
                                ? 'Reveal hidden to see details.'
                                : '${row['description'] ?? ''}\n${row['base_status_xp'] ?? '—'} base StatusXP',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _hidden(row)
                              ? null
                              : () => context.push(
                                  AchievementRef(
                                    gameRef: widget.game,
                                    platformAchievementId:
                                        row['platform_achievement_id']
                                            .toString(),
                                  ).location,
                                ),
                        ),
                      if (pages > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Previous achievements',
                              onPressed: page > 0
                                  ? () => setState(() => _page = page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('${page + 1} / $pages'),
                            IconButton(
                              tooltip: 'Next achievements',
                              onPressed: page + 1 < pages
                                  ? () => setState(() => _page = page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
