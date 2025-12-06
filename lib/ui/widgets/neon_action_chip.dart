import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Neon action chip - Floating pill button with glass effect
/// 
/// Used for quick actions like Sync PSN, View Games, etc.
class NeonActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool isPrimary;
  
  const NeonActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accentColor,
    this.isPrimary = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? CyberpunkTheme.neonCyan;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : CyberpunkTheme.glassLight,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: color.withOpacity(isPrimary ? 0.7 : 0.35),
            width: isPrimary ? 2 : 1,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: color,
              shadows: isPrimary
                  ? [
                      Shadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12,
                shadows: isPrimary
                    ? [
                        Shadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
