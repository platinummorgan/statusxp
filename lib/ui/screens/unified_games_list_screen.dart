import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Sort options for games list
enum GameSort {
  lastPlayed,
  lastTrophy,
  nameAsc,
  nameDesc,
  rarity,
}

/// Platform filter state provider (null = All)
final platformFilterProvider = StateProvider<String?>((ref) => null);

/// Sort state provider
final gameSortProvider = StateProvider<GameSort>((ref) => GameSort.nameAsc);

/// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Unified Games List Screen - Shows all games across all platforms
class UnifiedGamesListScreen extends ConsumerWidget {
  const UnifiedGamesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(unifiedGamesProvider);
    final platformFilter = ref.watch(platformFilterProvider);
    final sortOption = ref.watch(gameSortProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
        centerTitle: true,
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: Column(
          children: [
            gamesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (games) => _buildHeader(context, games, platformFilter),
            ),
            _buildSearchBar(context, ref),
            _buildFiltersAndSort(context, ref, platformFilter, sortOption),
            Expanded(
              child: gamesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading games: $error'),
                    ],
                  ),
                ),
                data: (games) {
                  final filteredGames = _filterAndSortGames(games, platformFilter, sortOption, searchQuery);
                  return _buildGamesList(context, ref, filteredGames);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<UnifiedGame> games, String? currentFilter) {
    // Calculate game counts per platform
    int psCount = 0;
    int xboxCount = 0;
    int steamCount = 0;

    for (final game in games) {
      for (final platform in game.platforms) {
        final platformCode = platform.platform.toLowerCase();
        
        // Check platform type - be more flexible with matching
        if (platformCode.contains('ps') || platformCode == 'playstation') {
          psCount++;
        } else if (platformCode.contains('xbox') || platformCode == 'xbox one' || platformCode == 'xboxone') {
          xboxCount++;
        } else if (platformCode == 'steam' || platformCode.contains('steam')) {
          steamCount++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Games: PS:$psCount • XBOX:$xboxCount • Steam:$steamCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (value) {
          ref.read(searchQueryProvider.notifier).state = value;
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search games...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersAndSort(BuildContext context, WidgetRef ref, String? currentFilter, GameSort currentSort) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, ref, null, 'All', currentFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'playstation', 'PlayStation', currentFilter,
                      color: const Color(0xFF00A8E1)),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'xbox', 'XBOX', currentFilter,
                      color: const Color(0xFF107C10)),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'steam', 'Steam', currentFilter,
                      color: const Color(0xFF66C0F4)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortDropdown(context, ref, currentSort),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref,
    String? filter,
    String label,
    String? currentFilter, {
    Color? color,
  }) {
    final isSelected = currentFilter == filter;
    final chipColor = color ?? CyberpunkTheme.neonCyan;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(platformFilterProvider.notifier).state = filter;
      },
      backgroundColor: Colors.black.withOpacity(0.3),
      selectedColor: chipColor.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? chipColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : Colors.white24,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context, WidgetRef ref, GameSort currentSort) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<GameSort>(
        value: currentSort,
        onChanged: (GameSort? newValue) {
          if (newValue != null) {
            ref.read(gameSortProvider.notifier).state = newValue;
          }
        },
        dropdownColor: const Color(0xFF0A0E27),
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        items: const [
          DropdownMenuItem(value: GameSort.lastPlayed, child: Text('Last Played')),
          DropdownMenuItem(value: GameSort.lastTrophy, child: Text('Last Trophy')),
          DropdownMenuItem(value: GameSort.nameAsc, child: Text('ABC Ascending')),
          DropdownMenuItem(value: GameSort.nameDesc, child: Text('ABC Descending')),
          DropdownMenuItem(value: GameSort.rarity, child: Text('Rarity')),
        ],
      ),
    );
  }

  List<UnifiedGame> _filterAndSortGames(
    List<UnifiedGame> games,
    String? platformFilter,
    GameSort sortOption,
    String searchQuery,
  ) {
    var filtered = games;

    // Apply platform filter
    if (platformFilter != null) {
      filtered = filtered.where((game) => game.isOnPlatform(platformFilter)).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((game) => game.title.toLowerCase().contains(query)).toList();
    }

    // Apply sorting
    switch (sortOption) {
      case GameSort.nameAsc:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case GameSort.nameDesc:
        filtered.sort((a, b) => b.title.compareTo(a.title));
        break;
      case GameSort.lastPlayed:
        // TODO: Implement when we have last_played_at data
        break;
      case GameSort.lastTrophy:
        // TODO: Implement when we have last trophy earned data
        break;
      case GameSort.rarity:
        // TODO: Implement rarity-based sorting
        break;
    }

    return filtered;
  }

  Widget _buildGamesList(BuildContext context, WidgetRef ref, List<UnifiedGame> games) {
    if (games.isEmpty) {
      return const Center(
        child: Text(
          'No games found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (context, index) {
        return _buildGameCard(context, games[index]);
      },
    );
  }

  Widget _buildGameCard(BuildContext context, UnifiedGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0E27).withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to game detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.coverUrl != null
                    ? Image.network(
                        game.coverUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                      )
                    : _buildPlaceholderCover(),
              ),
              const SizedBox(width: 12),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusXPBadge(game),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPlatformPills(game),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.black38,
      child: const Icon(Icons.videogame_asset, color: Colors.white24, size: 40),
    );
  }

  Widget _buildStatusXPBadge(UnifiedGame game) {
    // TODO: Calculate actual StatusXP from achievements
    // For now, use a placeholder based on completion
    final statusXP = (game.overallCompletion * 50).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CyberpunkTheme.neonOrange, width: 2),
      ),
      child: Text(
        'StatusXP $statusXP',
        style: TextStyle(
          color: CyberpunkTheme.neonOrange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlatformPills(UnifiedGame game) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: game.platforms.map((platform) {
        return _buildPlatformPill(platform);
      }).toList(),
    );
  }

  Widget _buildPlatformPill(PlatformGameData platform) {
    Color color;
    String label;
    
    final platformLower = platform.platform.toLowerCase();
    final platformOriginal = platform.platform;
    
    if (platformLower.contains('ps') || platformLower == 'playstation') {
      color = const Color(0xFF00A8E1);
      // Try to extract variant (PS4, PS5, etc.)
      if (platformOriginal.toUpperCase().contains('PS4')) {
        label = 'PS4';
      } else if (platformOriginal.toUpperCase().contains('PS5')) {
        label = 'PS5';
      } else if (platformOriginal.toUpperCase().contains('PS3')) {
        label = 'PS3';
      } else if (platformOriginal.toUpperCase().contains('VITA')) {
        label = 'PSVITA';
      } else {
        label = 'PlayStation';
      }
    } else if (platformLower.contains('xbox')) {
      color = const Color(0xFF107C10);
      // Extract Xbox variant
      if (platformOriginal.toUpperCase().contains('360')) {
        label = 'XBOX 360';
      } else if (platformOriginal.toUpperCase().contains('ONE')) {
        label = 'XBOX ONE';
      } else if (platformOriginal.toUpperCase().contains('SERIES')) {
        label = 'XBOX SERIES';
      } else {
        label = 'XBOX';
      }
    } else if (platformLower.contains('steam')) {
      color = const Color(0xFF66C0F4);
      label = 'Steam';
    } else {
      color = Colors.grey;
      label = platform.platform.toUpperCase();
    }

    final completion = platform.completion.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$label: ${platform.achievementsEarned}/${platform.achievementsTotal} $completion%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
