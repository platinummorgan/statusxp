import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/achievement_presentation.dart';
import 'package:statusxp/ui/widgets/game_achievement_card.dart';
import 'package:statusxp/ui/screens/ai_credit_shop_screen.dart';
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
                    ? 'platform_achievement_id,name,description,metadata,base_status_xp,icon_url,proxied_icon_url,rarity_global'
                    : 'platform_achievement_id,earned_at',
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
          ? {
              for (final row in results[1])
                row['platform_achievement_id']: row['earned_at'],
            }
          : <dynamic, dynamic>{};
      return results.first
          .map(
            (row) => <String, dynamic>{
              ...row,
              'earned': earned.containsKey(row['platform_achievement_id']),
              'earned_at': earned[row['platform_achievement_id']],
            },
          )
          .toList();
    });

/// Inline catalog with independent loading and state retained while collapsed.
class GameAchievementSection extends ConsumerStatefulWidget {
  const GameAchievementSection({
    super.key,
    required this.game,
    this.gameName = 'Game',
  });
  final GameRef game;
  final String gameName;

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
  final Map<String, bool> _expandedGroups = {'Base Game': true};
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
    final platform = widget.game.platform?.code ?? '';
    final platformColor = platform.startsWith('ps')
        ? const Color(0xFF0070CC)
        : platform.startsWith('xbox')
        ? const Color(0xFF107C10)
        : const Color(0xFF00D4FF);
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
              if (signedIn)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Buy AI Credits'),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AICreditShopScreen(),
                        ),
                      );
                      if (mounted) ref.invalidate(achievementCreditsProvider);
                    },
                  ),
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
                  final catalog =
                      rows
                          .asMap()
                          .entries
                          .map(
                            (entry) =>
                                achievementPresentation(entry.value, entry.key),
                          )
                          .toList()
                        ..sort(
                          (a, b) =>
                              compareAchievementPresentation(a, b, platform),
                        );
                  final filtered = catalog.where((row) {
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
                  final visibleGroups = <String, List<Map<String, dynamic>>>{};
                  for (final row
                      in filtered.skip(page * _pageSize).take(_pageSize)) {
                    visibleGroups
                        .putIfAbsent(achievementGroup(row), () => [])
                        .add(row);
                  }
                  return Column(
                    children: [
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No achievements match.'),
                        ),
                      for (final group in visibleGroups.entries)
                        ExpansionTile(
                          key: ValueKey('${group.key}:$page:$_filter:$_query'),
                          initiallyExpanded:
                              _query.isNotEmpty ||
                              (_expandedGroups[group.key] ?? false),
                          onExpansionChanged: (value) =>
                              _expandedGroups[group.key] = value,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          leading: Icon(
                            group.key == 'Base Game'
                                ? Icons.stars
                                : Icons.extension,
                            color: platformColor,
                          ),
                          title: Text(group.key),
                          subtitle: Text(
                            '${catalog.where((row) => achievementGroup(row) == group.key && row['earned'] == true).length} / ${catalog.where((row) => achievementGroup(row) == group.key).length} earned',
                          ),
                          children: [
                            for (final row in group.value)
                              GameAchievementCard(
                                key: ValueKey(row['platform_achievement_id']),
                                achievement: row,
                                platformId: widget.game.platformId,
                                platformGameId: widget.game.platformGameId,
                                gameName: widget.gameName,
                                platform: platform,
                                platformColor: platformColor,
                                showHidden: _reveal,
                              ),
                          ],
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
