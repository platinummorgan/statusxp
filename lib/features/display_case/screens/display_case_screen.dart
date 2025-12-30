import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/playstation_theme.dart';
import 'package:statusxp/features/display_case/widgets/trophy_frame.dart';
import 'package:statusxp/features/display_case/widgets/ps_symbol_frame.dart';
import 'package:statusxp/features/display_case/widgets/trophy_details_popup.dart';
import 'package:statusxp/features/display_case/dialogs/trophy_selector_dialog.dart';
import 'package:statusxp/features/display_case/providers/display_case_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';

/// Main Display Case screen with drag-and-drop grid layout
class DisplayCaseScreen extends ConsumerStatefulWidget {
  const DisplayCaseScreen({super.key});

  @override
  ConsumerState<DisplayCaseScreen> createState() => _DisplayCaseScreenState();
}

class _DisplayCaseScreenState extends ConsumerState<DisplayCaseScreen> {
  final theme = PlayStationTheme(); // TODO: Get from provider when settings added
  final config = const DisplayCaseConfig();
  List<DisplayCaseItem>? _cachedItems;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final userId = ref.read(currentUserIdProvider);
    final repository = ref.read(displayCaseRepositoryProvider);
    
    if (userId != null) {
      final items = await repository.getDisplayItems(userId);
      setState(() {
        _cachedItems = items;
      });
    }
  }



  void _removeItemLocally(String itemId) {
    if (_cachedItems == null) return;
    
    setState(() {
      _cachedItems!.removeWhere((item) => item.id == itemId);
    });
  }

  Future<void> _handleDeleteItem(String itemId) async {
    final repository = ref.read(displayCaseRepositoryProvider);
    final success = await repository.removeItem(itemId);
    
    if (success) {
      _removeItemLocally(itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final repository = ref.watch(displayCaseRepositoryProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a2332), // Dark blue-grey at top
              Color(0xFF0d1520), // Darker at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: _cachedItems == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.primaryAccent,
                  ),
                )
              : Stack(
                  children: [
                    // Main scrollable content
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 120, bottom: 20),
                      child: Column(
                        children: [
                          // Rarity Showcase with PS Symbol Frames
                          _buildRarityShowcase(userId!),
                          
                          const SizedBox(height: 30),
                          
                          // User Profile Banner
                          _buildProfileBanner(userId),
                          
                          const SizedBox(height: 30),
                          
                          // Achievement Categories (3 sections with 4 trophies each)
                          _buildAchievementCategories(_cachedItems!, repository, userId),
                          
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                    
                    // PlayStation header - stays on top
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1a2332),
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_esports,
                                color: Colors.white,
                                size: 40,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'PlayStation',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRarityShowcase(String userId) {
    final repository = ref.watch(displayCaseRepositoryProvider);
    
    return FutureBuilder<Map<String, DisplayCaseItem?>>(
      future: Future.wait([
        repository.getRarestTrophyOfTier(userId, 'platinum'),
        repository.getRarestTrophyOfTier(userId, 'silver'),
        repository.getRarestTrophyOfTier(userId, 'gold'),
        repository.getRarestTrophyOfTier(userId, 'bronze'),
      ]).then((results) => {
        'platinum': results[0],
        'silver': results[1],
        'gold': results[2],
        'bronze': results[3],
      }),
      builder: (context, snapshot) {
        final rarestPlatinum = snapshot.data?['platinum'];
        final rarestSilver = snapshot.data?['silver'];
        final rarestGold = snapshot.data?['gold'];
        final rarestBronze = snapshot.data?['bronze'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (rarestPlatinum != null)
            PSSymbolFrame(
              item: rarestPlatinum,
              theme: theme,
              symbol: PSSymbol.triangle,
              label: 'Rarest',
              onTap: () => showTrophyDetailsPopup(
                context,
                rarestPlatinum,
                theme,
                onDelete: null, // Rarity showcase is auto-populated, no manual delete
              ),
            )
          else
            _buildEmptySymbolSlot(PSSymbol.triangle, 'Rarest'),
            
          if (rarestSilver != null)
            PSSymbolFrame(
              item: rarestSilver,
              theme: theme,
              symbol: PSSymbol.square,
              label: 'Rarest Silver',
              onTap: () => showTrophyDetailsPopup(
                context,
                rarestSilver,
                theme,
                onDelete: null,
              ),
            )
          else
            _buildEmptySymbolSlot(PSSymbol.square, 'Rarest Silver'),
            
          if (rarestGold != null)
            PSSymbolFrame(
              item: rarestGold,
              theme: theme,
              symbol: PSSymbol.circle,
              label: 'Rarest Gold',
              onTap: () => showTrophyDetailsPopup(
                context,
                rarestGold,
                theme,
                onDelete: null,
              ),
            )
          else
            _buildEmptySymbolSlot(PSSymbol.circle, 'Rarest Gold'),
            
          if (rarestBronze != null)
            PSSymbolFrame(
              item: rarestBronze,
              theme: theme,
              symbol: PSSymbol.cross,
              label: 'Rarest Bronze',
              onTap: () => showTrophyDetailsPopup(
                context,
                rarestBronze,
                theme,
                onDelete: null,
              ),
            )
          else
            _buildEmptySymbolSlot(PSSymbol.cross, 'Rarest Bronze'),
        ],
      ),
    );
      },
    );
  }

  Widget _buildEmptySymbolSlot(PSSymbol symbol, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: EmptySymbolPainter(symbol: symbol),
            child: const Center(
              child: Icon(Icons.add, size: 30, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBanner(String userId) {
    final userStatsAsync = ref.watch(userStatsProvider);

    return userStatsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryAccent.withOpacity(0.3),
              theme.primaryAccent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryAccent, width: 2),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: theme.primaryAccent,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (error, stack) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryAccent.withOpacity(0.3),
              theme.primaryAccent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryAccent, width: 2),
        ),
        child: Row(
          children: [
            PsnAvatar(
              avatarUrl: null,
              isPsPlus: false,
              size: 60,
              borderColor: theme.primaryAccent,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wall of Fame!',
                    style: TextStyle(
                      color: theme.primaryAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      data: (stats) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryAccent.withOpacity(0.3),
              theme.primaryAccent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryAccent, width: 2),
        ),
        child: Row(
          children: [
            PsnAvatar(
              avatarUrl: stats.avatarUrl,
              isPsPlus: stats.isPsPlus,
              size: 60,
              borderColor: theme.primaryAccent,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wall of Fame!',
                    style: TextStyle(
                      color: theme.primaryAccent,
                      fontSize: 14,
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

  Widget _buildAchievementCategories(List<DisplayCaseItem> items, dynamic repository, String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Row 1: Positions 0-3
          _buildCategoryRow(
            ['Hardest', 'Easiest', 'Most Aggravating', 'Rage-Inducing'], 
            items, 
            repository, 
            userId,
            startPosition: 0,
          ),
          
          const SizedBox(height: 24),
          
          // Row 2: Positions 4-7
          _buildCategoryRow(
            ['Biggest Grind', 'Most Time-Consuming', 'RNG Nightmare', 'Never Again'], 
            items, 
            repository, 
            userId,
            startPosition: 4,
          ),
          
          const SizedBox(height: 24),
          
          // Row 3: Positions 8-11
          _buildCategoryRow(
            ['Most Proud Of', 'Most Fun', 'Hidden Gem', 'Signature Trophy'], 
            items, 
            repository, 
            userId,
            startPosition: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    List<String> categories, 
    List<DisplayCaseItem> items, 
    dynamic repository, 
    String userId, {
    required int startPosition,
  }) {
    return Row(
      children: [
        for (int i = 0; i < categories.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 32, // Fixed height for label area
                    alignment: Alignment.center,
                    child: Text(
                      categories[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Trophy slot with tap handling
                  SizedBox(
                    width: 70,
                    height: 90,
                    child: _buildCategoryTrophySlot(items, userId, startPosition + i),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryTrophySlot(List<DisplayCaseItem> items, String userId, int position) {
    // Find trophy for this specific position in shelf 0 (category shelf)
    final categoryItem = items.where((item) => 
      item.shelfNumber == 0 && item.positionInShelf == position
    ).firstOrNull;

    if (categoryItem != null) {
      // Get current logged-in user ID to check ownership
      final currentUserId = ref.read(currentUserIdProvider);
      final isOwnWall = currentUserId == categoryItem.userId;
      
      return GestureDetector(
        onTap: () {
          showTrophyDetailsPopup(
            context, 
            categoryItem, 
            theme,
            // Only allow delete if viewing your own wall
            onDelete: isOwnWall ? () async {
              await _handleDeleteItem(categoryItem.id);
            } : null,
          );
        },
        child: TrophyFrame(
          item: categoryItem,
          theme: theme,
        ),
      );
    }

    // Empty slot - tap to select trophy
    return GestureDetector(
      onTap: () async {
        // Open trophy selector
        final success = await showTrophySelectorDialog(context, 0, position);
        
        // Reload items after selection (if successful)
        if (success == true) {
          await _loadItems();
        }
      },
      child: TrophyFrame(
        item: DisplayCaseItem(
          id: '',
          userId: userId,
          trophyId: -1,
          displayType: DisplayItemType.trophyIcon,
          shelfNumber: 0,
          positionInShelf: position,
          trophyName: '',
          gameName: '',
          tier: 'bronze',
        ),
        theme: theme,
      ),
    );
  }
}
