import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/flex_room_data.dart';
import 'package:statusxp/data/repositories/flex_room_repository.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/game_achievements_screen.dart';
import 'package:statusxp/ui/widgets/achievement_picker_modal.dart';

import 'package:statusxp/ui/widgets/psn_avatar.dart';
import 'package:statusxp/ui/widgets/title_selector_modal.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Flex Room - Cross-platform curated museum of gaming achievements
/// User's hand-picked showcase across PS / Xbox / Steam
enum FlexRoomViewTab { showcase, recent }

class FlexRoomScreen extends ConsumerStatefulWidget {
  final String?
  viewerId; // If null, show current user's room. If provided, show that user's room.

  const FlexRoomScreen({super.key, this.viewerId});

  @override
  ConsumerState<FlexRoomScreen> createState() => _FlexRoomScreenState();
}

class _FlexRoomScreenState extends ConsumerState<FlexRoomScreen> {
  bool _isEditMode = false;
  FlexRoomViewTab _activeTab = FlexRoomViewTab.showcase;
  FlexRoomData? _editingData;
  FlexRoomData?
  _savedData; // Cache of last saved/loaded data to prevent flicker
  String? _avatarUrl;
  bool _isPsPlus = false;
  String _username = 'Player';
  String _selectedTitle = 'Completionist'; // Default title
  String? _achievementIcon; // Icon emoji for selected achievement title

  Future<void> _toggleEditMode(String userId) async {
    if (_isEditMode && _editingData != null) {
      final dataToSave = _editingData!;

      setState(() {
        _savedData = dataToSave;
        _isEditMode = false;
        _editingData = null;
      });

      final repository = ref.read(flexRoomRepositoryProvider);
      final success = await repository.updateFlexRoomData(dataToSave);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Flex Room saved!')));
      } else {
        ref.invalidate(flexRoomDataProvider(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save changes'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isEditMode = true;
      _activeTab = FlexRoomViewTab.showcase;
    });
  }

  @override
  void initState() {
    super.initState();
    // Load profile after the first frame to ensure ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile when navigating back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    final currentUserId = ref.read(currentUserIdProvider);
    final userId =
        widget.viewerId ??
        currentUserId ??
        ''; // View someone else's profile or your own
    final supabase = Supabase.instance.client;

    try {
      final profile = await supabase
          .from('profiles')
          .select(
            'psn_online_id, psn_avatar_url, psn_is_plus, steam_display_name, steam_avatar_url, xbox_gamertag, xbox_avatar_url, preferred_display_platform',
          )
          .eq('id', userId)
          .single();
      if (mounted) {
        final preferredPlatform =
            profile['preferred_display_platform'] as String? ?? 'psn';
        setState(() {
          // Use preferred platform for display
          switch (preferredPlatform) {
            case 'steam':
              _username = profile['steam_display_name'] as String? ?? 'Player';
              _avatarUrl = profile['steam_avatar_url'] as String?;
              break;
            case 'xbox':
              _username = profile['xbox_gamertag'] as String? ?? 'Player';
              _avatarUrl = profile['xbox_avatar_url'] as String?;
              break;
            case 'psn':
            default:
              _username = profile['psn_online_id'] as String? ?? 'Player';
              _avatarUrl = profile['psn_avatar_url'] as String?;
              _isPsPlus = profile['psn_is_plus'] as bool? ?? false;
          }
        });
      } else {}

      // Load selected title
      final titleData = await supabase
          .from('user_selected_title')
          .select(
            'achievement_id, custom_title, meta_achievements!inner(default_title, icon_emoji)',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (titleData != null && mounted) {
        setState(() {
          _selectedTitle =
              titleData['custom_title'] as String? ??
              (titleData['meta_achievements']?['default_title'] as String?) ??
              'Completionist';
          _achievementIcon =
              titleData['meta_achievements']?['icon_emoji'] as String?;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final userId =
        widget.viewerId ??
        currentUserId ??
        ''; // View someone else's room or your own
    final isOwner =
        userId == currentUserId && currentUserId != null; // Only owner can edit
    final flexRoomAsyncValue = ref.watch(flexRoomDataProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flex Room', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          // Edit Mode Toggle - only show for owner
          if (isOwner)
            IconButton(
              icon: Icon(
                _isEditMode ? Icons.check : Icons.edit,
                color: _isEditMode ? CyberpunkTheme.neonOrange : Colors.white,
              ),
              onPressed: () => _toggleEditMode(userId),
            ),
        ],
      ),
      body: flexRoomAsyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              CyberpunkTheme.neonPurple,
            ),
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: CyberpunkTheme.neonOrange.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load Flex Room',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (flexRoomData) {
          if (flexRoomData == null) {
            return Center(
              child: Text(
                'No Flex Room data available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
            );
          }

          // Initialize editing data when entering edit mode
          if (_isEditMode && _editingData == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _editingData = _savedData ?? flexRoomData;
              });
            });
          }

          // Update saved data cache only on first load
          _savedData ??= flexRoomData;

          // Show editing data in edit mode, otherwise show saved/cached data
          final displayData = _isEditMode && _editingData != null
              ? _editingData!
              : (_savedData ?? flexRoomData);

          return _buildFlexRoomContent(displayData, isOwner, userId);
        },
      ),
    );
  }

  Widget _buildFlexRoomContent(
    FlexRoomData flexRoomData,
    bool isOwner,
    String userId,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1a1f3a).withOpacity(0.8),
            const Color(0xFF0A0E27),
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Banner
            _buildHeroBanner(flexRoomData, isOwner),

            const SizedBox(height: 16),

            if (isOwner) _buildOwnerEditAction(userId),

            const SizedBox(height: 16),

            _buildViewTabSwitcher(),

            const SizedBox(height: 20),

            if (_activeTab == FlexRoomViewTab.showcase) ...[
              _buildCrossPlatformFlexRow(flexRoomData),
              const SizedBox(height: 28),
              _buildFlexStatsStrip(flexRoomData),
              const SizedBox(height: 28),
              _buildSuperlativeWall(flexRoomData),
            ] else ...[
              _buildFlexStatsStrip(flexRoomData),
              const SizedBox(height: 20),
              _buildRecentFlexes(flexRoomData, showEmptyState: true),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerEditAction(String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isEditMode
                ? CyberpunkTheme.neonOrange.withOpacity(0.5)
                : CyberpunkTheme.neonCyan.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isEditMode ? Icons.edit_note : Icons.tune,
              color: _isEditMode
                  ? CyberpunkTheme.neonOrange
                  : CyberpunkTheme.neonCyan,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isEditMode
                    ? 'Edit mode is active. Tap save when done.'
                    : 'Customize your showcase cards and highlights.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _toggleEditMode(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode
                    ? CyberpunkTheme.neonOrange
                    : CyberpunkTheme.neonCyan,
                foregroundColor: const Color(0xFF050814),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isEditMode ? 'Save' : 'Edit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CyberpunkTheme.neonPurple.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                tab: FlexRoomViewTab.showcase,
                label: 'Showcase',
                icon: Icons.auto_awesome,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTabButton(
                tab: FlexRoomViewTab.recent,
                label: 'Recent Flexes',
                icon: Icons.history,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required FlexRoomViewTab tab,
    required String label,
    required IconData icon,
  }) {
    final isActive = _activeTab == tab;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (_activeTab != tab) {
          setState(() {
            _activeTab = tab;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? CyberpunkTheme.neonPurple.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? CyberpunkTheme.neonPurple.withOpacity(0.75)
                : Colors.white.withOpacity(0.12),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: CyberpunkTheme.neonPurple.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? CyberpunkTheme.neonCyan
                  : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.76),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(FlexRoomData data, bool isOwner) {
    final daysSinceUpdate = DateTime.now().difference(data.lastUpdated).inDays;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CyberpunkTheme.neonPurple.withOpacity(0.1),
            CyberpunkTheme.neonOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CyberpunkTheme.neonPurple.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: CyberpunkTheme.neonPurple.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          PsnAvatar(
            avatarUrl: _avatarUrl,
            isPsPlus: _isPsPlus,
            size: 96,
            borderColor: CyberpunkTheme.neonCyan,
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            _username,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: CyberpunkTheme.neonPurple.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tagline (tappable to select title)
          InkWell(
            onTap: isOwner
                ? () async {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;

                    final newTitle = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => TitleSelectorModal(
                        userId: userId,
                        currentTitleId: null, // TODO: Track current title ID
                      ),
                    );

                    if (newTitle != null && mounted) {
                      setState(() {
                        _selectedTitle = newTitle;
                      });
                      // Reload profile to get the new icon
                      _loadUserProfile();
                    }
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CyberpunkTheme.neonOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CyberpunkTheme.neonOrange.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_achievementIcon != null) ...[
                    Text(
                      _achievementIcon!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _selectedTitle,
                    style: const TextStyle(
                      color: CyberpunkTheme.neonOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: CyberpunkTheme.neonOrange.withOpacity(0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Last Updated
          Text(
            daysSinceUpdate == 0
                ? 'Updated today'
                : 'Last updated $daysSinceUpdate ${daysSinceUpdate == 1 ? 'day' : 'days'} ago',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossPlatformFlexRow(FlexRoomData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'CROSS-PLATFORM FLEX',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: kIsWeb ? 0.85 : 0.82,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFlexCard(
                'Flex of All Time',
                data.flexOfAllTime,
                CyberpunkTheme.neonPurple,
                'flex_of_all_time',
                data,
                useGridLayout: true,
              ),
              _buildFlexCard(
                'Rarest Flex',
                data.rarestFlex,
                CyberpunkTheme.neonOrange,
                'rarest_flex',
                data,
                useGridLayout: true,
              ),
              _buildFlexCard(
                'Most Time-Sunk',
                data.mostTimeSunk,
                CyberpunkTheme.neonCyan,
                'most_time_sunk',
                data,
                useGridLayout: true,
              ),
              _buildFlexCard(
                'Sweatiest Platinum',
                data.sweattiestPlatinum,
                const Color(0xFFFF1744),
                'sweatiest_platinum',
                data,
                useGridLayout: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlexCard(
    String label,
    FlexTile? tile,
    Color accentColor,
    String categoryId,
    FlexRoomData data, {
    bool useGridLayout = false,
  }) {
    return InkWell(
      onTap: tile != null && !_isEditMode
          ? () => _showAchievementDetailsDialog(tile, label)
          : null,
      child: Stack(
        children: [
          Container(
            width: useGridLayout ? double.infinity : (kIsWeb ? 120 : 160),
            margin: useGridLayout
                ? EdgeInsets.zero
                : const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E27).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tile != null
                    ? accentColor
                    : Colors.white.withOpacity(0.1),
                width: 2,
              ),
              boxShadow: tile != null
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: tile != null
                ? _buildFilledFlexCard(tile, label, accentColor)
                : _buildEmptyFlexCard(label, accentColor, categoryId, data),
          ),
          // Delete button in edit mode
          if (_isEditMode && tile != null)
            Positioned(
              top: 4,
              right: useGridLayout ? 4 : 16,
              child: InkWell(
                onTap: () {
                  // Remove the cross-platform flex tile
                  FlexRoomData updatedData;
                  switch (categoryId) {
                    case 'flex_of_all_time':
                      updatedData = data.copyWith(
                        flexOfAllTime: null,
                        lastUpdated: DateTime.now(),
                      );
                      break;
                    case 'rarest_flex':
                      updatedData = data.copyWith(
                        rarestFlex: null,
                        lastUpdated: DateTime.now(),
                      );
                      break;
                    case 'most_time_sunk':
                      updatedData = data.copyWith(
                        mostTimeSunk: null,
                        lastUpdated: DateTime.now(),
                      );
                      break;
                    case 'sweatiest_platinum':
                      updatedData = data.copyWith(
                        sweattiestPlatinum: null,
                        lastUpdated: DateTime.now(),
                      );
                      break;
                    default:
                      return;
                  }

                  setState(() {
                    _editingData = updatedData;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilledFlexCard(FlexTile tile, String label, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Game Cover
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: tile.gameCoverUrl != null
                ? Image.network(
                    tile.gameCoverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.videogame_asset, size: 48),
                    ),
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.videogame_asset, size: 48),
                  ),
          ),
        ),

        // Info
        Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Platform Icon + Label
              Row(
                children: [
                  Icon(
                    _getPlatformIcon(tile.platform),
                    size: 12,
                    color: _getPlatformColor(tile.platform),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Achievement Name
              Text(
                tile.achievementName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (tile.rarityPercent != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRarityColor(tile.rarityBand).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(tile.rarityPercent ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _getRarityColor(tile.rarityBand),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFlexCard(
    String label,
    Color accentColor,
    String categoryId,
    FlexRoomData currentData,
  ) {
    return InkWell(
      onTap: _isEditMode
          ? () async {
              // Get smart suggestions for this category
              final repository = ref.read(flexRoomRepositoryProvider);
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;

              // TODO: Re-enable when SQL functions are executed
              // final suggestions =
              //     await repository.getSmartSuggestions(userId, categoryId);

              if (!mounted) return;

              // Show achievement picker
              final selected = await showModalBottomSheet<FlexTile>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AchievementPickerModal(
                  userId: userId,
                  categoryId: categoryId,
                  categoryLabel: label,
                  suggestions: const [], // Disabled for performance
                ),
              );

              if (selected != null && mounted) {
                // Update local editing data
                setState(() {
                  _editingData = (currentData).copyWith(
                    flexOfAllTime: categoryId == 'flex_of_all_time'
                        ? selected
                        : currentData.flexOfAllTime,
                    rarestFlex: categoryId == 'rarest_flex'
                        ? selected
                        : currentData.rarestFlex,
                    mostTimeSunk: categoryId == 'most_time_sunk'
                        ? selected
                        : currentData.mostTimeSunk,
                    sweattiestPlatinum: categoryId == 'sweatiest_platinum'
                        ? selected
                        : currentData.sweattiestPlatinum,
                    lastUpdated: DateTime.now(),
                  );
                });
              }
            }
          : null,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: accentColor.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isEditMode) ...[
              const SizedBox(height: 4),
              Text(
                'Tap to add',
                style: TextStyle(
                  color: accentColor.withOpacity(0.7),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlexStatsStrip(FlexRoomData data) {
    // Collect all flex tiles
    final allTiles = <FlexTile>[
      if (data.flexOfAllTime != null) data.flexOfAllTime!,
      if (data.rarestFlex != null) data.rarestFlex!,
      if (data.mostTimeSunk != null) data.mostTimeSunk!,
      if (data.sweattiestPlatinum != null) data.sweattiestPlatinum!,
      ...data.superlatives.values,
    ];

    // Calculate stats
    final rarestRarity = allTiles.isNotEmpty
        ? allTiles
              .where((t) => t.rarityPercent != null)
              .map((t) => t.rarityPercent!)
              .fold<double>(100.0, (min, val) => val < min ? val : min)
        : 0.0;

    final avgRarity = allTiles.isNotEmpty
        ? allTiles
                  .where((t) => t.rarityPercent != null)
                  .map((t) => t.rarityPercent!)
                  .fold<double>(0.0, (sum, val) => sum + val) /
              allTiles.where((t) => t.rarityPercent != null).length
        : 0.0;

    final totalFlexXP = allTiles
        .where((t) => t.statusXP != null)
        .map((t) => t.statusXP!)
        .fold<int>(0, (sum, val) => sum + val);

    final platforms = allTiles.map((t) => t.platform).toSet().length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Rarest',
            '${rarestRarity.toStringAsFixed(1)}%',
            CyberpunkTheme.neonOrange,
          ),
          _buildStatItem(
            'Avg Rarity',
            '${avgRarity.toStringAsFixed(1)}%',
            CyberpunkTheme.neonPurple,
          ),
          _buildStatItem(
            'Flex XP',
            _formatFlexXP(totalFlexXP),
            CyberpunkTheme.neonPurple,
          ),
          _buildStatItem('Platforms', '$platforms', Colors.white),
        ],
      ),
    );
  }

  String _formatFlexXP(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return xp.toString();
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSuperlativeWall(FlexRoomData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'SUPERLATIVE WALL',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final category = SuperlativeCategory.all[index];
              final tile = data.superlatives[category['id']];

              return _buildSuperlativeTile(
                category['label']!,
                category['id']!,
                tile,
                data,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuperlativeTile(
    String label,
    String categoryId,
    FlexTile? tile,
    FlexRoomData currentData,
  ) {
    final isEmpty = tile == null;

    return InkWell(
      onTap: _isEditMode
          ? () async {
              // Get smart suggestions for this category
              final repository = ref.read(flexRoomRepositoryProvider);
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;

              // TODO: Re-enable when SQL functions are executed
              // final suggestions =
              //     await repository.getSmartSuggestions(userId, categoryId);

              if (!mounted) return;

              // Show achievement picker
              final selected = await showModalBottomSheet<FlexTile>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AchievementPickerModal(
                  userId: userId,
                  categoryId: categoryId,
                  categoryLabel: label,
                  suggestions: const [], // Disabled for performance
                ),
              );

              if (selected != null && mounted) {
                // Update superlatives map
                final newSuperlatives = Map<String, FlexTile>.from(
                  currentData.superlatives,
                );
                newSuperlatives[categoryId] = selected;

                setState(() {
                  _editingData = currentData.copyWith(
                    superlatives: newSuperlatives,
                    lastUpdated: DateTime.now(),
                  );
                });
              }
            }
          : isEmpty
          ? null
          : () => _showAchievementDetailsDialog(tile, label),
      onLongPress: !isEmpty && _isEditMode
          ? () {
              // Show remove option
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1a1f3a),
                  title: Text(
                    'Remove $label?',
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final newSuperlatives = Map<String, FlexTile>.from(
                          currentData.superlatives,
                        );
                        newSuperlatives.remove(categoryId);

                        setState(() {
                          _editingData = currentData.copyWith(
                            superlatives: newSuperlatives,
                            lastUpdated: DateTime.now(),
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: CyberpunkTheme.neonOrange),
                      ),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isEmpty
              ? const Color(0xFF1a1f3a).withOpacity(0.3)
              : const Color(0xFF0A0E27).withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEmpty
                ? CyberpunkTheme.neonOrange.withOpacity(0.2)
                : CyberpunkTheme.neonOrange.withOpacity(0.5),
            width: isEmpty ? 1 : 2,
          ),
        ),
        child: Stack(
          children: [
            isEmpty
                ? _buildEmptySuperlativeTile(label)
                : _buildFilledSuperlativeTile(tile),
            // Delete button in edit mode
            if (_isEditMode && !isEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () {
                    final newSuperlatives = Map<String, FlexTile>.from(
                      currentData.superlatives,
                    );
                    newSuperlatives.remove(categoryId);

                    setState(() {
                      _editingData = currentData.copyWith(
                        superlatives: newSuperlatives,
                        lastUpdated: DateTime.now(),
                      );
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySuperlativeTile(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 32,
            color: CyberpunkTheme.neonOrange.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.add_circle,
              size: 16,
              color: CyberpunkTheme.neonOrange.withOpacity(0.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilledSuperlativeTile(FlexTile tile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Achievement Icon or Game Cover
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPlatformColor(tile.platform).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPlatformColor(tile.platform).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: tile.iconUrl != null
                  ? Image.network(
                      tile.iconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        _getPlatformIcon(tile.platform),
                        size: 32,
                        color: _getPlatformColor(tile.platform),
                      ),
                    )
                  : Icon(
                      _getPlatformIcon(tile.platform),
                      size: 32,
                      color: _getPlatformColor(tile.platform),
                    ),
            ),
          ),
        ),

        // Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    tile.achievementName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                if (tile.rarityPercent != null)
                  Text(
                    '${(tile.rarityPercent ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _getRarityColor(tile.rarityBand),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFlexes(FlexRoomData data, {bool showEmptyState = false}) {
    if (data.recentFlexes.isEmpty) {
      if (!showEmptyState) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CyberpunkTheme.neonCyan.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 28,
              color: Colors.white.withOpacity(0.45),
            ),
            const SizedBox(height: 8),
            Text(
              'No recent flexes yet.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'After your next sync, new achievements will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'RECENT FLEXES',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),

        const SizedBox(height: 12),

        ...data.recentFlexes.map((flex) => _buildRecentFlexCard(flex)),
      ],
    );
  }

  Widget _buildRecentFlexCard(RecentFlex flex) {
    final daysAgo = DateTime.now().difference(flex.earnedAt).inDays;
    final timeText = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
        ? '1 day ago'
        : '$daysAgo days ago';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRarityColor(flex.rarityBand).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Platform Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPlatformColor(flex.platform).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getPlatformIcon(flex.platform),
              size: 24,
              color: _getPlatformColor(flex.platform),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flex.gameName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  flex.achievementName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Rarity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRarityColor(flex.rarityBand).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getRarityColor(flex.rarityBand),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${flex.rarityPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _getRarityColor(flex.rarityBand),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  flex.rarityBand.replaceAll('_', ' '),
                  style: TextStyle(
                    color: _getRarityColor(flex.rarityBand).withOpacity(0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Achievement Details Dialog
  void _showAchievementDetailsDialog(FlexTile tile, String categoryLabel) {
    showDialog(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.86;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400, maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E27),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CyberpunkTheme.neonOrange.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CyberpunkTheme.neonOrange.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with close button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              categoryLabel.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CyberpunkTheme.neonOrange,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Achievement Icon (large)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPlatformColor(
                            tile.platform,
                          ).withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getPlatformColor(
                              tile.platform,
                            ).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: tile.iconUrl != null
                            ? Image.network(
                                tile.iconUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  _getPlatformIcon(tile.platform),
                                  size: 60,
                                  color: _getPlatformColor(tile.platform),
                                ),
                              )
                            : Icon(
                                _getPlatformIcon(tile.platform),
                                size: 60,
                                color: _getPlatformColor(tile.platform),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Achievement Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        tile.achievementName,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Game Name with Cover
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (tile.gameCoverUrl != null) ...[
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  tile.gameCoverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              tile.gameName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1f3a).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CyberpunkTheme.neonPurple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Rarity & StatusXP
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogStatItem(
                                    'RARITY',
                                    '${tile.rarityPercent?.toStringAsFixed(1) ?? '0.0'}%',
                                    _getRarityColor(tile.rarityBand),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                Expanded(
                                  child: _buildDialogStatItem(
                                    'STATUS XP',
                                    '${tile.statusXP}',
                                    CyberpunkTheme.neonCyan,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Rarity Band & Platform
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogStatItem(
                                    'TIER',
                                    tile.rarityBand?.replaceAll('_', ' ') ??
                                        'COMMON',
                                    _getRarityColor(tile.rarityBand),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Icon(
                                        _getPlatformIcon(tile.platform),
                                        size: 24,
                                        color: _getPlatformColor(tile.platform),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tile.platform.toUpperCase(),
                                        style: TextStyle(
                                          color: _getPlatformColor(
                                            tile.platform,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Earned Date
                            Text(
                              'Earned ${_formatEarnedDate(tile.earnedAt ?? DateTime.now())}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // View Trophy List Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            if (tile.gameId != null ||
                                tile.platformGameId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => GameAchievementsScreen(
                                    platformId: tile.platformId,
                                    platformGameId:
                                        tile.platformGameId ?? tile.gameId,
                                    gameName: tile.gameName,
                                    platform: tile.platform,
                                    coverUrl: tile.gameCoverUrl,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPlatformColor(tile.platform),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Icon(Icons.list, size: 20),
                              Text(
                                'VIEW TROPHY LIST',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogStatItem(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _formatEarnedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  // Helper methods
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
}
