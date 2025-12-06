import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// PSN Profile Avatar with optional PS Plus badge overlay
/// 
/// Displays a circular avatar with neon border and PS Plus indicator
class PsnAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool isPsPlus;
  final double size;
  final Color borderColor;
  
  const PsnAvatar({
    super.key,
    this.avatarUrl,
    this.isPsPlus = false,
    this.size = 56,
    this.borderColor = CyberpunkTheme.neonCyan,
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Avatar with neon border
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: borderColor.withOpacity(0.3),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _DefaultAvatar(size: size, borderColor: borderColor);
                      },
                    )
                  : _DefaultAvatar(size: size, borderColor: borderColor),
            ),
          ),
          
          // PS Plus badge overlay (bottom right)
          if (isPsPlus)
            Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox(
                width: size * 0.45,
                height: size * 0.45,
                child: Image.asset(
                  'assets/images/ps_plus_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Default avatar widget when no image is available
class _DefaultAvatar extends StatelessWidget {
  final double size;
  final Color borderColor;
  
  const _DefaultAvatar({
    required this.size,
    required this.borderColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: CyberpunkTheme.glassDark,
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: borderColor.withOpacity(0.5),
      ),
    );
  }
}
