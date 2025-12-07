import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Platform filter state provider
final platformFilterProvider = StateProvider<String?>((ref) => null); // null = All

/// Unified Games List Screen - Shows all games across all platforms
class UnifiedGamesListScreen extends ConsumerWidget {
  const UnifiedGamesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(unifiedGamesProvider);
    final platformFilter = ref.watch(platformFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
        centerTitle: true,
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: Column(
          children: [
            _buildFilterChips(context, ref, platformFilter),
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
                  final filteredGames = _filterGames(games, platformFilter);
                  return _buildGamesList(context, ref, filteredGames);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, String? currentFilter) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(context, ref, null, 'All', currentFilter),
            const SizedBox(width: 8),
            _buildFilterChip(context, ref, 'playstation', 'PlayStation', currentFilter,
                color: const Color(0xFF00A8E1)),
            const SizedBox(width: 8),
            _buildFilterChip(context, ref, 'xbox', 'Xbox', currentFilter,
                color: const Color(0xFF107C10)),
            const SizedBox(width: 8),
            _buildFilterChip(context, ref, 'steam', 'Steam', currentFilter,
                color: const Color(0xFF66C0F4)),
          ],
        ),
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
      ),
      side: BorderSide(
        color: isSelected ? chipColor : Colors.white24,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  List<UnifiedGame> _filterGames(List<UnifiedGame> games, String? platformFilter) {
    if (platformFilter == null) {
      return games;
    }
    return games.where((game) => game.isOnPlatform(platformFilter)).toList();
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
            children: [
              // Game cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.coverUrl != null
                    ? Image.network(
                        game.coverUrl!,
                        width: 60,
                        height: 60,
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
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildPlatformBadges(game),
                    const SizedBox(height: 4),
                    _buildCompletionBar(game.overallCompletion),
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
      width: 60,
      height: 60,
      color: Colors.black38,
      child: const Icon(Icons.videogame_asset, color: Colors.white24),
    );
  }

  Widget _buildPlatformBadges(UnifiedGame game) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: game.platforms.map((platform) {
        return _buildPlatformBadge(platform);
      }).toList(),
    );
  }

  Widget _buildPlatformBadge(PlatformGameData platform) {
    Color color;
    String label;
    
    switch (platform.platform) {
      case 'playstation':
        color = const Color(0xFF00A8E1);
        label = 'PS';
        break;
      case 'xbox':
        color = const Color(0xFF107C10);
        label = 'XB';
        break;
      case 'steam':
        color = const Color(0xFF66C0F4);
        label = 'ST';
        break;
      default:
        color = Colors.grey;
        label = platform.platform.substring(0, 2).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${platform.achievementsEarned}/${platform.achievementsTotal}',
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBar(double completion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall: ${completion.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: completion / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(
              completion == 100 ? CyberpunkTheme.goldNeon : CyberpunkTheme.neonCyan,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
