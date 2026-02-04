import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/game_achievements_screen.dart';

/// Screen for browsing ALL games in the database
/// Allows users to explore games they don't own
class GameBrowserScreen extends ConsumerStatefulWidget {
  const GameBrowserScreen({super.key});

  @override
  ConsumerState<GameBrowserScreen> createState() => _GameBrowserScreenState();
}

class _GameBrowserScreenState extends ConsumerState<GameBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _games = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 50;
  String? _platformFilter;
  String _searchQuery = '';
  bool _isGridView = false; // Toggle between grid and list view - default to list
  String _sortBy = 'name_asc'; // Default sort

  @override
  void initState() {
    super.initState();
    _loadGames();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadGames() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _offset = 0;
      _games = [];
    });

    try {
      final repository = ref.read(gameRepositoryProvider);
      final games = await repository.getAllGames(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        platformFilter: _platformFilter,
        limit: _limit,
        offset: _offset,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _games = games;
          _hasMore = games.length == _limit;
          _offset = _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(gameRepositoryProvider);
      final games = await repository.getAllGames(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        platformFilter: _platformFilter,
        limit: _limit,
        offset: _offset,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _games.addAll(games);
          _hasMore = games.length == _limit;
          _offset += _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch(String value) {
    setState(() => _searchQuery = value);
    _loadGames();
  }

  void _onPlatformFilter(String? platform) {
    setState(() => _platformFilter = platform);
    _loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        title: const Text(
          'GAME CATALOG',
          style: TextStyle(
            color: CyberpunkTheme.neonCyan,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: CyberpunkTheme.neonCyan),
            tooltip: 'Sort',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _loadGames();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name_asc',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: _sortBy == 'name_asc' ? CyberpunkTheme.neonCyan : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'A → Z',
                      style: TextStyle(
                        color: _sortBy == 'name_asc' ? CyberpunkTheme.neonCyan : Colors.white,
                        fontWeight: _sortBy == 'name_asc' ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name_desc',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: _sortBy == 'name_desc' ? CyberpunkTheme.neonCyan : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Z → A',
                      style: TextStyle(
                        color: _sortBy == 'name_desc' ? CyberpunkTheme.neonCyan : Colors.white,
                        fontWeight: _sortBy == 'name_desc' ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            color: const Color(0xFF1a1f3a),
            elevation: 8,
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: CyberpunkTheme.neonCyan,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search games...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: CyberpunkTheme.neonCyan),
                filled: true,
                fillColor: const Color(0xFF1a1f3a).withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: CyberpunkTheme.neonCyan,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Platform Filter Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('PlayStation', 'psn'),
                const SizedBox(width: 8),
                _buildFilterChip('Xbox', 'xbox'),
                const SizedBox(width: 8),
                _buildFilterChip('Steam', 'steam'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Games Grid or List
          Expanded(
            child: _games.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videogame_asset_off,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No games found',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _games.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _games.length) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: CyberpunkTheme.neonCyan,
                              ),
                            );
                          }

                          final game = _games[index];
                          return _buildGameCard(game);
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _games.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _games.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: CyberpunkTheme.neonCyan,
                                ),
                              ),
                            );
                          }

                          final game = _games[index];
                          return _buildGameListItem(game);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showPlatformSelectionDialog(BuildContext context, Map<String, dynamic> game) {
    final name = game['name'] as String? ?? 'Unknown Game';
    final allPlatforms = game['all_platforms'] as List<dynamic>? ?? [];
    final platformNames = game['platform_names'] as List<dynamic>? ?? [];
    final platformIds = game['platform_ids'] as List<dynamic>? ?? [];
    final platformGameIds = game['platform_game_ids'] as List<dynamic>? ?? [];
    final coverUrl = kIsWeb ? (game['proxied_cover_url'] ?? game['cover_url']) as String? : game['cover_url'] as String?;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                  name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ...allPlatforms.asMap().entries.map((entry) {
                  final index = entry.key;
                  final platformCode = entry.value;
                  
                  // Get platform_id and platform_game_id for this platform
                  final platformId = index < platformIds.length ? platformIds[index] : null;
                  final platformGameId = index < platformGameIds.length ? platformGameIds[index] : null;
                  final platformName = index < platformNames.length ? platformNames[index].toString() : platformCode.toString();
                  
                  Color platformColor;
                  IconData platformIcon;

                  final code = platformCode.toString().toLowerCase();
                  if (code.contains('ps') || code == 'playstation') {
                    platformColor = const Color(0xFF0070CC);
                    platformIcon = Icons.sports_esports;
                  } else if (code.contains('xbox')) {
                    platformColor = const Color(0xFF107C10);
                    platformIcon = Icons.videogame_asset;
                  } else if (code.contains('steam')) {
                    platformColor = const Color(0xFF1B2838);
                    platformIcon = Icons.store;
                  } else {
                    platformColor = Colors.grey;
                    platformIcon = Icons.gamepad;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(dialogContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GameAchievementsScreen(
                              platformId: platformId,
                              platformGameId: platformGameId?.toString(),
                              gameName: name,
                              platform: platformCode.toString(),
                              coverUrl: coverUrl,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: platformColor,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(platformIcon, color: platformColor, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                platformName,
                                style: TextStyle(
                                  color: platformColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String? platformCode) {
    final isSelected = _platformFilter == platformCode;
    
    return FilterChip(
      label: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => _onPlatformFilter(selected ? platformCode : null),
      backgroundColor: const Color(0xFF1a1f3a).withOpacity(0.5),
      selectedColor: CyberpunkTheme.neonCyan,
      checkmarkColor: Colors.black,
      side: BorderSide(
        color: isSelected
            ? CyberpunkTheme.neonCyan
            : CyberpunkTheme.neonCyan.withOpacity(0.3),
        width: 1.5,
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final name = game['name'] as String? ?? 'Unknown Game';
    final coverUrl = kIsWeb ? (game['proxied_cover_url'] ?? game['cover_url']) as String? : game['cover_url'] as String?;
    final platformId = game['platform_id'];
    final platformGameId = game['platform_game_id'];
    final platformData = game['platforms'] as Map<String, dynamic>?;
    final platformCode = platformData?['code'] as String? ?? '';
    final allPlatforms = game['all_platforms'] as List<dynamic>? ?? [platformCode];

    return GestureDetector(
      onTap: () {
        if (platformGameId != null) {
          // Show platform selector if game has multiple platforms
          if (allPlatforms.length > 1) {
            _showPlatformSelectionDialog(context, game);
          } else {
            // Navigate directly to achievements for single-platform games
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameAchievementsScreen(
                  platformId: platformId,
                  platformGameId: platformGameId?.toString(),
                  gameName: name,
                  platform: _platformFilter ?? platformCode,
                  coverUrl: coverUrl,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1f3a).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getPlatformColor(_platformFilter ?? platformCode).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game Cover
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF0A0E27),
                          child: Icon(
                            _getPlatformIcon(platformCode),
                            size: 48,
                            color: _getPlatformColor(platformCode).withOpacity(0.5),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF0A0E27),
                        child: Icon(
                          _getPlatformIcon(platformCode),
                          size: 48,
                          color: _getPlatformColor(platformCode).withOpacity(0.5),
                        ),
                      ),
              ),
            ),

            // Game Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Show all platforms for multi-platform games
                  Flexible(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: allPlatforms.map((platform) {
                      final platformStr = platform.toString();
                      final isFiltered = _platformFilter != null && 
                                        platformStr.toLowerCase() == _platformFilter!.toLowerCase();
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFiltered 
                              ? _getPlatformColor(platformStr).withOpacity(0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: _getPlatformColor(platformStr).withOpacity(isFiltered ? 1.0 : 0.5),
                            width: isFiltered ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPlatformIcon(platformStr),
                              size: 10,
                              color: _getPlatformColor(platformStr),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              platformStr.toUpperCase(),
                              style: TextStyle(
                                color: _getPlatformColor(platformStr),
                                fontSize: 9,
                                fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameListItem(Map<String, dynamic> game) {
    final name = game['name'] as String? ?? 'Unknown Game';
    final coverUrl = kIsWeb ? (game['proxied_cover_url'] ?? game['cover_url']) as String? : game['cover_url'] as String?;
    final platformId = game['platform_id'];
    final platformGameId = game['platform_game_id'];
    final platformData = game['platforms'] as Map<String, dynamic>?;
    final platformCode = platformData?['code'] as String? ?? '';
    final allPlatforms = game['all_platforms'] as List<dynamic>? ?? [platformCode];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (platformGameId != null) {
            // Show platform selector if game has multiple platforms
            if (allPlatforms.length > 1) {
              _showPlatformSelectionDialog(context, game);
            } else {
              // Navigate directly to achievements for single-platform games
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GameAchievementsScreen(
                    platformId: platformId,
                    platformGameId: platformGameId?.toString(),
                    gameName: name,
                    platform: _platformFilter ?? platformCode,
                    coverUrl: coverUrl,
                  ),
                ),
              );
            }
          }
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1f3a).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getPlatformColor(_platformFilter ?? platformCode).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Game Cover
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: SizedBox(
                  width: 80,
                  height: 100,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF0A0E27),
                            child: Icon(
                              _getPlatformIcon(platformCode),
                              size: 32,
                              color: _getPlatformColor(platformCode).withOpacity(0.5),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF0A0E27),
                          child: Icon(
                            _getPlatformIcon(platformCode),
                            size: 32,
                            color: _getPlatformColor(platformCode).withOpacity(0.5),
                          ),
                        ),
                ),
              ),

              // Game Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show all platforms for multi-platform games
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < allPlatforms.length; i++) ...[
                                Builder(
                                  builder: (context) {
                                    final platformStr = allPlatforms[i].toString();
                                    final isFiltered = _platformFilter != null && 
                                                      platformStr.toLowerCase() == _platformFilter!.toLowerCase();
                                    
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFiltered 
                                            ? _getPlatformColor(platformStr).withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _getPlatformColor(platformStr).withOpacity(isFiltered ? 1.0 : 0.5),
                                          width: isFiltered ? 1.5 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getPlatformIcon(platformStr),
                                            size: 12,
                                            color: _getPlatformColor(platformStr),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            platformStr.toUpperCase(),
                                            style: TextStyle(
                                              color: _getPlatformColor(platformStr),
                                              fontSize: 11,
                                              fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (i < allPlatforms.length - 1) const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'psn':
        return const Color(0xFF00A8E1);
      case 'xbox':
        return const Color(0xFF107C10);
      case 'steam':
        return const Color(0xFF66C0F4);
      default:
        return Colors.grey;
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'psn':
        return Icons.videogame_asset;
      case 'xbox':
        return Icons.sports_esports;
      case 'steam':
        return Icons.computer;
      default:
        return Icons.gamepad;
    }
  }
}
