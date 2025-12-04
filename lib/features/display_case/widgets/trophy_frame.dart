import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// Picture frame widget with 3D depth effect for trophy icons
class TrophyFrame extends StatelessWidget {
  final DisplayCaseItem item;
  final DisplayCaseTheme theme;

  const TrophyFrame({
    super.key,
    required this.item,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateX(0.05) // slight tilt for 3D effect
        ..rotateY(-0.05),
      alignment: Alignment.center,
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          // Outer frame shadow (depth)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Wooden frame border
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8B4513).withOpacity(0.9), // saddle brown
                    const Color(0xFF654321).withOpacity(0.9), // dark brown
                    const Color(0xFF3E2723).withOpacity(0.9), // darker brown
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFF5D4037),
                  width: 3,
                ),
                boxShadow: [
                  // Inner shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            
            // Inner gold/tier-colored trim
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.getTierColor(item.tier),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.getTierColor(item.tier).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Glass reflection effect
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.transparent,
                        Colors.white.withOpacity(0.1),
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            
            // Trophy icon in center
            Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: item.iconUrl != null
                    ? Image.network(
                        item.iconUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.emoji_events,
                          color: theme.getTierColor(item.tier),
                          size: 50,
                        ),
                      )
                    : Icon(
                        Icons.emoji_events,
                        color: theme.getTierColor(item.tier),
                        size: 50,
                      ),
              ),
            ),
            
            // Top highlight reflection
            Positioned(
              top: 12,
              left: 12,
              right: 40,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
