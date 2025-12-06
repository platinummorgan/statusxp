import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Glassmorphic panel component with neon border accent
/// 
/// A reusable container with frosted glass effect, thin neon borders,
/// and optional glow for the cyberpunk HUD aesthetic.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool showGlow;
  final EdgeInsetsGeometry? padding;
  
  const GlassPanel({
    super.key,
    required this.child,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius = 16,
    this.showGlow = false,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: CyberpunkTheme.glassBox(
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        showGlow: showGlow,
      ),
      child: child,
    );
  }
}

/// Horizontal stat display for glass panels
/// 
/// Shows a label and value in a compact horizontal layout
class GlassStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool showAccentDot;
  
  const GlassStat({
    super.key,
    required this.label,
    required this.value,
    this.accentColor = CyberpunkTheme.neonCyan,
    this.showAccentDot = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label with optional accent dot
        Row(
          children: [
            if (showAccentDot) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.8),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withOpacity(0.55),
                letterSpacing: 1.5,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        // Value with enhanced neon glow
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            height: 1,
            shadows: [
              ...CyberpunkTheme.neonGlow(color: accentColor, blurRadius: 10),
              Shadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
