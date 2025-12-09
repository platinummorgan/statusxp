import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/game_list_tile.dart';
import 'package:statusxp/ui/widgets/glass_panel.dart';
import 'package:statusxp/ui/screens/trophy_list_screen.dart';

enum GameSortOption {
  name,
  progress,
  rarity,
  lastPlayed,
  platinumEarned,
}

enum GameFilterOption {
  all,
  inProgress,
  platinumed,
  completedNoPlatinum,
  backlog,
}

/// Games List Screen
/// 
/// Displays all tracked games with trophy progress.
/// Shows completion percentage and platinum indicators.
class GamesListScreen extends ConsumerStatefulWidget {
  const GamesListScreen({super.key});

  @override
  ConsumerState<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends ConsumerState<GamesListScreen> {
  GameSortOption _sortBy = GameSortOption.lastPlayed;
  GameFilterOption _filterBy = GameFilterOption.all;
  bool _sortAscending = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Game> _applySortingAndFiltering(List<Game> games) {
    // Apply filter
    var filtered = games.where((game) {
      switch (_filterBy) {
        case GameFilterOption.all:
          return true;
        case GameFilterOption.inProgress:
          return game.earnedTrophies > 0 && game.earnedTrophies < game.totalTrophies;
        case GameFilterOption.platinumed:
          return game.hasPlatinum && game.earnedTrophies == game.totalTrophies;
        case GameFilterOption.completedNoPlatinum:
          return !game.hasPlatinum && game.earnedTrophies == game.totalTrophies;
        case GameFilterOption.backlog:
          return game.earnedTrophies == 0;
      }
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case GameSortOption.name:
          return a.name.compareTo(b.name);
        case GameSortOption.progress:
          final aProgress = a.totalTrophies > 0 ? (a.earnedTrophies / a.totalTrophies) : 0;
          final bProgress = b.totalTrophies > 0 ? (b.earnedTrophies / b.totalTrophies) : 0;
          return bProgress.compareTo(aProgress);
        case GameSortOption.rarity:
          // Games without rarity (platinumRarity == null) go to the bottom
          final aRarity = a.platinumRarity ?? double.infinity;
          final bRarity = b.platinumRarity ?? double.infinity;
          return aRarity.compareTo(bRarity);
        case GameSortOption.lastPlayed:
          // Sort by updatedAt (most recent first)
          final aTime = a.updatedAt ?? DateTime(1970);
          final bTime = b.updatedAt ?? DateTime(1970);
          if (aTime.year == 1970 && bTime.year == 1970) {
            // Both have no timestamp, sort by name
            return a.name.compareTo(b.name);
          }
          return bTime.compareTo(aTime);
        case GameSortOption.platinumEarned:
          // Platinumed games first
          if (a.hasPlatinum != b.hasPlatinum) {
            return a.hasPlatinum ? -1 : 1;
          }
          // If both have platinum or both don't, sort by name
          return a.name.compareTo(b.name);
      }
    });

    // Reverse if descending
    if (!_sortAscending) {
      filtered = filtered.reversed.toList();
    }

    return filtered;
  }

  String _getSortLabel(GameSortOption option) {
    switch (option) {
      case GameSortOption.name:
        return 'Name';
      case GameSortOption.progress:
        return 'Progress';
      case GameSortOption.rarity:
        return 'Rarity';
      case GameSortOption.lastPlayed:
        return 'Last Played';
      case GameSortOption.platinumEarned:
        return 'Platinum';
    }
  }

  String _getFilterLabel(GameFilterOption option) {
    switch (option) {
      case GameFilterOption.all:
        return 'All';
      case GameFilterOption.inProgress:
        return 'In Progress';
      case GameFilterOption.platinumed:
        return 'Platinumed';
      case GameFilterOption.completedNoPlatinum:
        return '100% (no plat)';
      case GameFilterOption.backlog:
        return 'Backlog';
    }
  }

  void _showSortBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: CyberpunkTheme.neonCyan.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SORT GAMES',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan, blurRadius: 4),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: CyberpunkTheme.neonCyan),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            
              // Sort options
              ...GameSortOption.values.map((option) {
                final isSelected = _sortBy == option;
                return ListTile(
                  leading: Icon(
                    _getSortIcon(option),
                    color: isSelected ? CyberpunkTheme.neonCyan : Colors.white60,
                  ),
                  title: Text(
                    _getSortLabel(option),
                    style: TextStyle(
                      color: isSelected ? CyberpunkTheme.neonCyan : Colors.white,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _getSortDescription(option),
                    style: TextStyle(
                      color: isSelected ? CyberpunkTheme.neonCyan.withOpacity(0.7) : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected 
                    ? const Icon(Icons.check, color: CyberpunkTheme.neonCyan)
                    : null,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _sortBy = option;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                    Navigator.pop(context);
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }),
            
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSortIcon(GameSortOption option) {
    switch (option) {
      case GameSortOption.name:
        return Icons.sort_by_alpha;
      case GameSortOption.progress:
        return Icons.show_chart;
      case GameSortOption.rarity:
        return Icons.star_outline;
      case GameSortOption.lastPlayed:
        return Icons.access_time;
      case GameSortOption.platinumEarned:
        return Icons.emoji_events;
    }
  }

  String _getSortDescription(GameSortOption option) {
    switch (option) {
      case GameSortOption.name:
        return 'Alphabetical order';
      case GameSortOption.progress:
        return 'By completion percentage';
      case GameSortOption.rarity:
        return 'By platinum rarity (rarest first)';
      case GameSortOption.lastPlayed:
        return 'Most recently played';
      case GameSortOption.platinumEarned:
        return 'Platinumed games first';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'GAMES',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan),
          ),
        ),
        leading: BackButton(
          color: CyberpunkTheme.neonCyan,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        actions: [
          // Sort direction toggle button
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            color: CyberpunkTheme.neonCyan,
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _sortAscending = !_sortAscending;
              });
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
          // Sort option button - opens bottom sheet
          IconButton(
            icon: const Icon(Icons.sort),
            color: CyberpunkTheme.neonCyan,
            tooltip: 'Sort by',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showSortBottomSheet(context);
            },
          ),
        ],
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: gamesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
            ),
          ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading games',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        data: (games) {
          // Check if user has no games yet
          if (games.isEmpty) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: GlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videogame_asset_off_outlined,
                            size: 80,
                            color: CyberpunkTheme.neonCyan,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'NO GAMES IMPORTED',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sync your PlayStation Network trophies to see your games here',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/psn-sync'),
                            icon: const Icon(Icons.cloud_sync),
                            label: const Text('SYNC PSN TROPHIES'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CyberpunkTheme.neonCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                              elevation: 8,
                              shadowColor: CyberpunkTheme.neonCyan.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          
          // Apply sorting and filtering
          final filteredGames = _applySortingAndFiltering(games);
          
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 80), // Space for transparent app bar
            // Header with stats in glass panel
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${filteredGames.length} GAMES TRACKED',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan, blurRadius: 4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: CyberpunkTheme.neonPurple, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${games.where((g) => g.hasPlatinum).length} Platinums',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: CyberpunkTheme.neonPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.sort, color: CyberpunkTheme.neonCyan, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _getSortLabel(_sortBy),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: CyberpunkTheme.neonCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Filter chips with neon styling
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: GameFilterOption.values.map((option) {
                  final isSelected = _filterBy == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _filterBy = option;
                          });
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                              ? CyberpunkTheme.neonCyan.withOpacity(0.15)
                              : CyberpunkTheme.glassDark.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected 
                                ? CyberpunkTheme.neonCyan
                                : CyberpunkTheme.glassLight.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ] : null,
                          ),
                          child: Text(
                            _getFilterLabel(option),
                            style: TextStyle(
                              color: isSelected ? CyberpunkTheme.neonCyan : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Games list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(gamesProvider);
                  await ref.read(gamesProvider.future);
                },
                child: filteredGames.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: GlassPanel(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.filter_list_off,
                                  size: 64,
                                  color: CyberpunkTheme.neonCyan,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'NO GAMES MATCH',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try a different filter option',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filteredGames.length,
                      itemBuilder: (context, index) {
                        final game = filteredGames[index];
                        return GameListTile(
                          game: game,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrophyListScreen(game: game),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ),
          ],
        );
        },
        ),
      ),
    );
  }
}
