import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/playstation_theme.dart';
import 'package:statusxp/features/display_case/widgets/display_item.dart';
import 'package:statusxp/features/display_case/widgets/trophy_details_popup.dart';
import 'package:statusxp/features/display_case/dialogs/trophy_selector_dialog.dart';
import 'package:statusxp/features/display_case/providers/display_case_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';

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
  bool _isLoading = true;

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
        _isLoading = false;
      });
    }
  }

  void _updateItemLocally(DisplayCaseItem oldItem, int newShelf, int newPosition) {
    if (_cachedItems == null) return;
    
    setState(() {
      // Find and update the item
      final index = _cachedItems!.indexWhere((item) => item.id == oldItem.id);
      if (index != -1) {
        _cachedItems![index] = oldItem.copyWith(
          shelfNumber: newShelf,
          positionInShelf: newPosition,
        );
      }
    });
  }

  void _swapItemsLocally(DisplayCaseItem item1, DisplayCaseItem item2) {
    if (_cachedItems == null) return;
    
    setState(() {
      final index1 = _cachedItems!.indexWhere((item) => item.id == item1.id);
      final index2 = _cachedItems!.indexWhere((item) => item.id == item2.id);
      
      if (index1 != -1 && index2 != -1) {
        // Swap positions
        _cachedItems![index1] = item1.copyWith(
          shelfNumber: item2.shelfNumber,
          positionInShelf: item2.positionInShelf,
        );
        
        _cachedItems![index2] = item2.copyWith(
          shelfNumber: item1.shelfNumber,
          positionInShelf: item1.positionInShelf,
        );
      }
    });
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
        title: Text(
          'DISPLAY CASE',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: theme.textGlow(color: theme.primaryAccent),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textColor),
      ),
      body: Container(
        decoration: theme.getBackgroundDecoration(),
        child: SafeArea(
          child: _cachedItems == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.primaryAccent,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      // Build shelves
                      for (int shelfIndex = 0; shelfIndex < config.numberOfShelves; shelfIndex++)
                        _buildShelf(shelfIndex, _cachedItems!, repository, userId!),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildShelf(
    int shelfIndex,
    List<DisplayCaseItem> allItems,
    dynamic repository,
    String userId,
  ) {
    // Get items for this shelf
    final shelfItems = allItems
        .where((item) => item.shelfNumber == shelfIndex)
        .toList();

    return Container(
      margin: EdgeInsets.only(bottom: config.shelfSpacing),
      height: config.shelfHeight,
      decoration: theme.getShelfDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int position = 0; position < config.itemsPerShelf; position++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildGridSlot(
                    shelfIndex,
                    position,
                    shelfItems,
                    repository,
                    userId,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSlot(
    int shelfNumber,
    int position,
    List<DisplayCaseItem> shelfItems,
    dynamic repository,
    String userId,
  ) {
    // Find item at this position
    final item = shelfItems.firstWhere(
      (item) => item.positionInShelf == position,
      orElse: () => DisplayCaseItem(
        id: '',
        userId: userId,
        trophyId: -1,
        displayType: DisplayItemType.trophyIcon,
        shelfNumber: shelfNumber,
        positionInShelf: position,
        trophyName: '',
        gameName: '',
        tier: '',
      ),
    );

    final hasItem = item.trophyId != -1;

    return DragTarget<DisplayCaseItem>(
      onWillAcceptWithDetails: (details) {
        // Accept if not dragging to the exact same position
        final isSamePosition = details.data.shelfNumber == shelfNumber && 
                                details.data.positionInShelf == position;
        print('DEBUG onWillAccept: shelf ${details.data.shelfNumber}:${details.data.positionInShelf} -> $shelfNumber:$position, same=$isSamePosition');
        return !isSamePosition;
      },
      onAcceptWithDetails: (details) async {
        final droppedItem = details.data;
        
        print('DEBUG: Dragging item from shelf ${droppedItem.shelfNumber}, pos ${droppedItem.positionInShelf}');
        print('DEBUG: Dropping to shelf $shelfNumber, pos $position');
        
        // Check if target position has an item
        final targetItem = shelfItems.firstWhere(
          (item) => item.positionInShelf == position,
          orElse: () => DisplayCaseItem(
            id: '',
            userId: userId,
            trophyId: -1,
            displayType: DisplayItemType.trophyIcon,
            shelfNumber: shelfNumber,
            positionInShelf: position,
            trophyName: '',
            gameName: '',
            tier: '',
          ),
        );

        bool success;
        if (targetItem.trophyId != -1) {
          // Target has an item, swap them
          print('DEBUG: Target occupied, swapping items');
          success = await repository.swapItems(droppedItem, targetItem);
        } else {
          // Target is empty, just move
          print('DEBUG: Target empty, moving item');
          success = await repository.updateItemPosition(
            itemId: droppedItem.id,
            newShelfNumber: shelfNumber,
            newPositionInShelf: position,
          );
        }

        print('DEBUG: Move success: $success');
        if (success) {
          // Update UI immediately without refresh
          if (targetItem.trophyId != -1) {
            _swapItemsLocally(droppedItem, targetItem);
          } else {
            _updateItemLocally(droppedItem, shelfNumber, position);
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        if (hasItem) {
          return Draggable<DisplayCaseItem>(
            data: item,
            dragAnchorStrategy: childDragAnchorStrategy,
            feedback: Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.2,
                child: Container(
                  width: 100,
                  height: 120,
                  child: DisplayItem(
                    item: item,
                    theme: theme,
                    isDragging: false,
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              width: 100,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.primaryAccent.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.north_east,
                  color: theme.primaryAccent.withOpacity(0.5),
                  size: 32,
                ),
              ),
            ),
            child: GestureDetector(
              onTap: () => showTrophyDetailsPopup(
                context,
                item,
                theme,
                // Only allow delete if this is the current user's display case
                onDelete: item.userId == userId ? () => _handleDeleteItem(item.id) : null,
              ),
              child: DisplayItem(
                item: item,
                theme: theme,
              ),
            ),
          );
        } else {
          return EmptyDisplaySlot(
            isHighlighted: false,
            theme: theme,
            onTap: () async {
              await showTrophySelectorDialog(context, shelfNumber, position);
              await _loadItems(); // Reload after adding trophy
            },
          );
        }
      },
    );
  }
}
