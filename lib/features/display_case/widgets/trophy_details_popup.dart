import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// Shows trophy details in a popup
void showTrophyDetailsPopup(
  BuildContext context,
  DisplayCaseItem item,
  DisplayCaseTheme theme, {
  Future<void> Function()? onDelete,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.backgroundColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.primaryAccent.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryAccent.withOpacity(0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy icon
            if (item.iconUrl != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.getTierColor(item.tier),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.getTierColor(item.tier).withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.iconUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.emoji_events,
                      color: theme.getTierColor(item.tier),
                      size: 40,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Trophy name
            Text(
              item.trophyName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                shadows: theme.textGlow(color: theme.getTierColor(item.tier)),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Game name
            Text(
              item.gameName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.getTierColor(item.tier).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.getTierColor(item.tier),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: theme.getTierColor(item.tier),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.tier.toUpperCase(),
                    style: TextStyle(
                      color: theme.getTierColor(item.tier),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            
            // Rarity
            if (item.rarity != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.primaryAccent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      color: theme.primaryAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.rarity!.toStringAsFixed(2)}% RARITY',
                      style: TextStyle(
                        color: theme.primaryAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Delete button
                if (onDelete != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await onDelete();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      backgroundColor: Colors.red.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'REMOVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (onDelete != null) const SizedBox(width: 12),
                
                // Close button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: theme.primaryAccent.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.primaryAccent, width: 1.5),
                    ),
                  ),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: theme.primaryAccent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
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
