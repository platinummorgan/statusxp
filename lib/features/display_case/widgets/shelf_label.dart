import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// A draggable decorative label for shelves
class ShelfLabel extends StatelessWidget {
  final String text;
  final DisplayCaseTheme theme;
  final VoidCallback? onTap;

  const ShelfLabel({
    super.key,
    required this.text,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryAccent.withOpacity(0.3),
              theme.primaryAccent.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.primaryAccent.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryAccent.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hanging chain effect
            Container(
              width: 2,
              height: 12,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade600,
                    Colors.grey.shade400,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Label text
            Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: theme.primaryAccent.withOpacity(0.8),
                    blurRadius: 4,
                  ),
                  const Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
