import 'package:flutter/material.dart';
import 'package:statusxp/ui/widgets/cross_platform_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/flex_room_repository.dart';
import 'package:statusxp/domain/flex_room_data.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Modal for selecting an achievement to assign to a Flex Room tile
/// Three-step selection: Platform → Game → Achievement (or use Smart Suggestions)
class AchievementPickerModal extends ConsumerStatefulWidget {
  final String userId;
  final String categoryId;
  final String categoryLabel;
  final List<FlexTile>? suggestions;

  const AchievementPickerModal({
    super.key,
    required this.userId,
    required this.categoryId,
    required this.categoryLabel,
    this.suggestions,
  });

  @override
  ConsumerState<AchievementPickerModal> createState() =>
      _AchievementPickerModalState();
}

enum PickerView { suggestions, platformSelect, gameSelect, achievementSelect }

class _AchievementPickerModalState
    extends ConsumerState<AchievementPickerModal> {
  PickerView _currentView = PickerView.platformSelect;
  String? _selectedPlatform;
  String? _selectedGameId;
  String? _selectedGameName;
  int? _selectedPlatformId;
  String? _selectedPlatformGameId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1a1f3a).withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with breadcrumb navigation
          _buildHeader(),

          // Content based on current view
          Expanded(
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;
    
    switch (_currentView) {
      case PickerView.suggestions:
        title = 'Smart Suggestions';
        subtitle = widget.categoryLabel;
        break;
      case PickerView.platformSelect:
        title = 'Select Platform';
        subtitle = widget.categoryLabel;
        break;
      case PickerView.gameSelect:
        title = 'Select Game';
        subtitle = _getPlatformName(_selectedPlatform!);
        break;
      case PickerView.achievementSelect:
        title = 'Select Achievement';
        subtitle = _selectedGameName ?? 'Game';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CyberpunkTheme.neonPurple.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button if not on first view
          if (_currentView != PickerView.platformSelect)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  switch (_currentView) {
                    case PickerView.suggestions:
                      _currentView = PickerView.platformSelect;
                      break;
                    case PickerView.gameSelect:
                      _currentView = PickerView.platformSelect;
                      _selectedPlatform = null;
                      break;
                    case PickerView.achievementSelect:
                      _currentView = PickerView.gameSelect;
                      _selectedGameId = null;
                      _selectedGameName = null;
                      _selectedPlatformId = null;
                      _selectedPlatformGameId = null;
                      break;
                    default:
                      break;
                  }
                });
              },
            ),
          const Icon(Icons.military_tech, color: CyberpunkTheme.neonOrange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: CyberpunkTheme.neonPurple.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CyberpunkTheme.neonOrange.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case PickerView.suggestions:
        return _buildSuggestionsView();
      case PickerView.platformSelect:
        return _buildPlatformSelectView();
      case PickerView.gameSelect:
        return _buildGameSelectView();
      case PickerView.achievementSelect:
        return _buildAchievementSelectView();
    }
  }

  Widget _buildPlatformSelectView() {
    final hasSuggestions = widget.suggestions != null && widget.suggestions!.isNotEmpty;
    
    return Column(
      children: [
        // Smart Suggestions button at top if available
        if (hasSuggestions) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPlatformCard(
              'Smart Suggestions',
              'AI-curated best picks for this category',
              Icons.auto_awesome,
              CyberpunkTheme.neonOrange,
              onTap: () {
                setState(() {
                  _currentView = PickerView.suggestions;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR BROWSE MANUALLY',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 24),

        // Platform selection cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildPlatformCard(
                'PlayStation',
                'Browse PS3, PS4, PS5, Vita trophies',
                Icons.videogame_asset,
                const Color(0xFF0070CC),
                onTap: () {
                  setState(() {
                    _selectedPlatform = 'psn';
                    _currentView = PickerView.gameSelect;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildPlatformCard(
                'Xbox',
                'Browse Xbox 360, Xbox One, Series X|S achievements',
                Icons.sports_esports,
                const Color(0xFF107C10),
                onTap: () {
                  setState(() {
                    _selectedPlatform = 'xbox';
                    _currentView = PickerView.gameSelect;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildPlatformCard(
                'Steam',
                'Browse Steam achievements',
                Icons.store,
                const Color(0xFF66C0F4),
                onTap: () {
                  setState(() {
                    _selectedPlatform = 'steam';
                    _currentView = PickerView.gameSelect;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformCard(
    String title,
    String description,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsView() {
    final suggestions = widget.suggestions!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final tile = suggestions[index];
        return _buildAchievementCard(tile, issuggestion: true);
      },
    );
  }

  Widget _buildGameSelectView() {
    // Safety check - if platform not selected, go back to platform select
    if (_selectedPlatform == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentView = PickerView.platformSelect);
        }
      });
      return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.neonPurple));
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search games...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(
                Icons.search,
                color: CyberpunkTheme.neonCyan.withOpacity(0.6),
              ),
              filled: true,
              fillColor: const Color(0xFF1a1f3a).withOpacity(0.6),
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
                borderSide: const BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
              ),
            ),
          ),
        ),

        // Games list
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(flexRoomRepositoryProvider).getGamesForPlatform(
                  widget.userId,
                  _selectedPlatform!,
                  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: CyberpunkTheme.neonPurple),
                );
              }

              if (snapshot.hasError) {
                print('❌ FutureBuilder error in getGamesForPlatform: ${snapshot.error}');
                print('Stack trace: ${snapshot.stackTrace}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.withOpacity(0.8), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading games',
                        style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final games = snapshot.data ?? [];

              if (games.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videogame_asset_off, color: Colors.white.withOpacity(0.4), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ? 'No games found' : 'No games yet',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _buildGameCard(game);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final gameName = game['game_name'] as String;
    final gameId = game['game_id'] as String?;
    final platformId = game['platform_id'] as int?;
    final platformGameId = game['platform_game_id'] as String?;
    final gameCoverUrl = game['game_cover_url'] as String?;
    final achievementCount = game['achievement_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getPlatformColor(_selectedPlatform!).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGameId = gameId;
            _selectedGameName = gameName;
            _selectedPlatformId = platformId;
            _selectedPlatformGameId = platformGameId;
            _currentView = PickerView.achievementSelect;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Game Cover
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _getPlatformColor(_selectedPlatform!).withOpacity(0.2),
                  border: Border.all(
                    color: _getPlatformColor(_selectedPlatform!).withOpacity(0.5),
                  ),
                ),
                child: gameCoverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CrossPlatformImage(
                          imageUrl: gameCoverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _getPlatformIcon(_selectedPlatform!),
                            color: _getPlatformColor(_selectedPlatform!),
                            size: 32,
                          ),
                        ),
                      )
                    : Icon(
                        _getPlatformIcon(_selectedPlatform!),
                        color: _getPlatformColor(_selectedPlatform!),
                        size: 32,
                      ),
              ),

              const SizedBox(width: 12),

              // Game Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$achievementCount ${achievementCount == 1 ? 'achievement' : 'achievements'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Icon(
                Icons.arrow_forward_ios,
                color: _getPlatformColor(_selectedPlatform!).withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementSelectView() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search achievements...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(
                Icons.search,
                color: CyberpunkTheme.neonCyan.withOpacity(0.6),
              ),
              filled: true,
              fillColor: const Color(0xFF1a1f3a).withOpacity(0.6),
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
                borderSide: const BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
              ),
            ),
          ),
        ),

        // Achievements list
        Expanded(
          child: FutureBuilder<List<FlexTile>>(
            future: ref.read(flexRoomRepositoryProvider).getAchievementsForGame(
                  widget.userId,
                  _selectedGameId,
                  _selectedPlatform!,
                  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                  platformId: _selectedPlatformId,
                  platformGameId: _selectedPlatformGameId,
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: CyberpunkTheme.neonPurple),
                );
              }

              if (snapshot.hasError) {
                print('❌ FutureBuilder error in getAchievementsForGame: ${snapshot.error}');
                print('Stack trace: ${snapshot.stackTrace}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.withOpacity(0.8), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading achievements',
                        style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final achievements = snapshot.data ?? [];

              if (achievements.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No achievements found' : 'No achievements yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final tile = achievements[index];
                  return _buildAchievementCard(tile);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(FlexTile tile, {bool issuggestion = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: issuggestion
              ? CyberpunkTheme.neonOrange.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: issuggestion ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(tile),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Game Cover or Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _getPlatformColor(tile.platform).withOpacity(0.2),
                  border: Border.all(
                    color: _getPlatformColor(tile.platform).withOpacity(0.5),
                  ),
                ),
                child: tile.gameCoverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CrossPlatformImage(
                          imageUrl: tile.gameCoverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _getPlatformIcon(tile.platform),
                            color: _getPlatformColor(tile.platform),
                            size: 32,
                          ),
                        ),
                      )
                    : Icon(
                        _getPlatformIcon(tile.platform),
                        color: _getPlatformColor(tile.platform),
                        size: 32,
                      ),
              ),

              const SizedBox(width: 12),

              // Achievement Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.achievementName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tile.gameName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tile.statusXP != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(tile.statusXP ?? 0).toStringAsFixed(1)} XP',
                        style: const TextStyle(
                          color: CyberpunkTheme.neonPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Rarity Badge
              if (tile.rarityPercent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRarityColor(tile.rarityBand).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getRarityColor(tile.rarityBand),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${(tile.rarityPercent ?? 0).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _getRarityColor(tile.rarityBand),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (tile.rarityBand != null)
                        Text(
                          tile.rarityBand!.replaceAll('_', ' '),
                          style: TextStyle(
                            color: _getRarityColor(
                              tile.rarityBand,
                            ).withOpacity(0.8),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

              if (issuggestion) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.auto_awesome,
                  color: CyberpunkTheme.neonOrange,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  Color _getRarityColor(String? rarityBand) {
    switch (rarityBand?.toUpperCase()) {
      case 'ULTRA_RARE':
        return const Color(0xFFFF1744);
      case 'VERY_RARE':
        return const Color(0xFFFF9100);
      case 'RARE':
        return const Color(0xFFFFD600);
      case 'UNCOMMON':
        return const Color(0xFF00E676);
      default:
        return Colors.grey;
    }
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'psn':
        return 'PlayStation';
      case 'xbox':
        return 'Xbox';
      case 'steam':
        return 'Steam';
      default:
        return platform;
    }
  }
}
