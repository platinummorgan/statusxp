import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/game_achievements_screen.dart';

/// Sort options for games list
enum GameSort {
  lastPlayed,
  lastTrophy,
  nameAsc,
  nameDesc,
  rarity,
}

/// Platform filter state provider (empty set = All)
final platformFilterProvider = StateProvider<Set<String>>((ref) => {});

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
              data: (games) => _buildHeader(context, ref, games, platformFilter),
            ),
            _buildSearchBar(context, ref, sortOption),
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

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<UnifiedGame> games, Set<String> selectedFilters) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(ref, 'PS', psCount, const Color(0xFF0070CC), Icons.videogame_asset, 'playstation', selectedFilters),
          _buildStatCard(ref, 'XBOX', xboxCount, const Color(0xFF107C10), Icons.sports_esports, 'xbox', selectedFilters),
          _buildStatCard(ref, 'Steam', steamCount, const Color(0xFF66C0F4), Icons.store, 'steam', selectedFilters),
        ],
      ),
    );
  }

  Widget _buildStatCard(WidgetRef ref, String label, int count, Color color, IconData icon, String filterValue, Set<String> selectedFilters) {
    final isSelected = selectedFilters.contains(filterValue);
    
    return Expanded(
      child: InkWell(
        onTap: () {
          // Toggle platform in/out of set (multi-select like Excel)
          final newFilters = Set<String>.from(selectedFilters);
          if (newFilters.contains(filterValue)) {
            newFilters.remove(filterValue);
          } else {
            newFilters.add(filterValue);
          }
          ref.read(platformFilterProvider.notifier).state = newFilters;
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(isSelected ? 0.5 : 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, GameSort currentSort) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                  borderSide: const BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildCompactSortButton(context, ref, currentSort),
        ],
      ),
    );
  }

  Widget _buildCompactSortButton(BuildContext context, WidgetRef ref, GameSort currentSort) {
    return PopupMenuButton<GameSort>(
      onSelected: (GameSort newValue) {
        ref.read(gameSortProvider.notifier).state = newValue;
      },
      color: const Color(0xFF0A0E27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CyberpunkTheme.neonOrange.withOpacity(0.5), width: 1),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<GameSort>>[
        const PopupMenuItem<GameSort>(
          value: GameSort.lastPlayed,
          child: Text('Last Played', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<GameSort>(
          value: GameSort.lastTrophy,
          child: Text('Last Trophy', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<GameSort>(
          value: GameSort.nameAsc,
          child: Text('ABC Ascending', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<GameSort>(
          value: GameSort.nameDesc,
          child: Text('ABC Descending', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem<GameSort>(
          value: GameSort.rarity,
          child: Text('Rarity', style: TextStyle(color: Colors.white)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CyberpunkTheme.neonOrange.withOpacity(0.5), width: 1.5),
        ),
        child: const Icon(
          Icons.sort,
          color: CyberpunkTheme.neonOrange,
          size: 24,
        ),
      ),
    );
  }

  List<UnifiedGame> _filterAndSortGames(
    List<UnifiedGame> games,
    Set<String> platformFilter,
    GameSort sortOption,
    String searchQuery,
  ) {
    var filtered = games;

    // Apply platform filter (multi-select: show games on ANY selected platform)
    if (platformFilter.isNotEmpty) {
      filtered = filtered.where((game) {
        return platformFilter.any((platform) => game.isOnPlatform(platform));
      }).toList();
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
        filtered.sort((a, b) {
          final aTime = a.getMostRecentPlayTime();
          final bTime = b.getMostRecentPlayTime();
          if (aTime == null && bTime == null) return a.title.compareTo(b.title);
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Most recent first
        });
        break;
      case GameSort.lastTrophy:
        // Same as lastPlayed for now (using last_played_at field)
        filtered.sort((a, b) {
          final aTime = a.getMostRecentPlayTime();
          final bTime = b.getMostRecentPlayTime();
          if (aTime == null && bTime == null) return a.title.compareTo(b.title);
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Most recent first
        });
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
          _handleGameTap(context, game);
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
    // Get total StatusXP across all platforms for this game
    final statusXP = game.getTotalStatusXP();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CyberpunkTheme.neonPurple, width: 2),
      ),
      child: Text(
        'StatusXP $statusXP',
        style: const TextStyle(
          color: CyberpunkTheme.neonPurple,
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

  void _handleGameTap(BuildContext context, UnifiedGame game) {
    if (game.platforms.length == 1) {
      // Only one platform - go directly to achievements
      final platform = game.platforms.first;
      _navigateToAchievements(context, game, platform);
    } else {
      // Multiple platforms - show selection dialog
      _showPlatformSelectionDialog(context, game);
    }
  }

  void _showPlatformSelectionDialog(BuildContext context, UnifiedGame game) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0A0E27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Platform',
                  style: TextStyle(
                    color: CyberpunkTheme.neonCyan,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ...game.platforms.map((platform) {
                  Color platformColor;
                  IconData platformIcon;
                  String platformLabel;

                  final platformCode = platform.platform.toLowerCase();
                  if (platformCode.contains('ps') || platformCode == 'playstation') {
                    platformColor = const Color(0xFF0070CC);
                    platformIcon = Icons.sports_esports;
                    platformLabel = 'PlayStation';
                  } else if (platformCode.contains('xbox')) {
                    platformColor = const Color(0xFF107C10);
                    platformIcon = Icons.videogame_asset;
                    platformLabel = 'Xbox';
                  } else if (platformCode.contains('steam')) {
                    platformColor = const Color(0xFF1B2838);
                    platformIcon = Icons.store;
                    platformLabel = 'Steam';
                  } else {
                    platformColor = Colors.grey;
                    platformIcon = Icons.gamepad;
                    platformLabel = platform.platform;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToAchievements(context, game, platform);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: platformColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(platformIcon, color: platformColor, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    platformLabel,
                                    style: TextStyle(
                                      color: platformColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${platform.achievementsEarned}/${platform.achievementsTotal} • ${platform.completion.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: platformColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToAchievements(BuildContext context, UnifiedGame game, PlatformGameData platform) {
    print('[UnifiedGamesList] Navigating to achievements:');
    print('  Game: ${game.title}');
    print('  GameId from platform: ${platform.gameId}');
    print('  Platform: ${platform.platform}');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameAchievementsScreen(
          gameId: platform.gameId,
          gameName: game.title,
          platform: platform.platform,
          coverUrl: game.coverUrl,
        ),
      ),
    );
  }
}

