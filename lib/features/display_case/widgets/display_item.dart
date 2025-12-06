import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// Draggable trophy display item
/// 
/// Renders a trophy icon or game cover with drag & drop support
class DisplayItem extends StatelessWidget {
  final DisplayCaseItem item;
  final DisplayCaseTheme theme;
  final VoidCallback? onTap;
  final bool isDragging;

  const DisplayItem({
    super.key,
    required this.item,
    required this.theme,
    this.onTap,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.getTierColor(item.tier).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.getTierColor(item.tier).withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: _buildItemContent(),
    );
  }

  Widget _buildItemContent() {
    switch (item.displayType) {
      case DisplayItemType.trophyIcon:
        return _buildTrophyIcon();
      case DisplayItemType.gameCover:
        return _buildGameCover();
      case DisplayItemType.figurine:
      case DisplayItemType.custom:
        return _buildPlaceholder();
    }
  }

  Widget _buildTrophyIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Trophy icon
        if (item.iconUrl != null)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.iconUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: theme.getTierColor(item.tier),
                ),
              ),
            ),
          )
        else
          Icon(
            Icons.emoji_events,
            size: 48,
            color: theme.getTierColor(item.tier),
          ),
        
        const SizedBox(height: 4),
        
        // Tier indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.getTierColor(item.tier).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.getTierColor(item.tier),
              width: 1,
            ),
          ),
          child: Text(
            item.tier.toUpperCase(),
            style: TextStyle(
              color: theme.getTierColor(item.tier),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Game cover image
          if (item.gameImageUrl != null)
            Image.network(
              item.gameImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          else
            _buildPlaceholder(),
          
          // Tier badge overlay
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.getTierColor(item.tier),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.emoji_events,
                size: 16,
                color: theme.getTierColor(item.tier),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: theme.shelfColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image,
        size: 48,
        color: theme.textColor.withOpacity(0.3),
      ),
    );
  }
}

/// Empty slot that can receive dropped items
class EmptyDisplaySlot extends StatelessWidget {
  final bool isHighlighted;
  final DisplayCaseTheme theme;
  final VoidCallback? onTap;

  const EmptyDisplaySlot({
    super.key,
    required this.isHighlighted,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isHighlighted 
              ? Border.all(
                  color: theme.primaryAccent.withOpacity(0.6),
                  width: 2,
                )
              : null,
        ),
        child: isHighlighted
            ? Icon(
                Icons.add_circle_outline,
                size: 36,
                color: theme.primaryAccent.withOpacity(0.8),
              )
            : Icon(
                Icons.add,
                size: 24,
                color: Colors.white.withOpacity(0.2),
              ),
      ),
    );
  }
}
