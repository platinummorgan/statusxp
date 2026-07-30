import 'package:flutter/material.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class DashboardGameCard extends StatelessWidget {
  const DashboardGameCard({
    required this.game,
    required this.platformPills,
    required this.onTap,
    super.key,
  });

  final UnifiedGame game;
  final Widget platformPills;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0E27).withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CyberpunkTheme.neonCyan.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.coverUrl == null
                    ? const _PlaceholderCover()
                    : Image.network(
                        game.coverUrl!,
                        width: 80,
                        height: 80,
                        cacheWidth: 240,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PlaceholderCover(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    platformPills,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: Colors.black38,
      child: const Icon(Icons.videogame_asset, color: Colors.white24, size: 40),
    );
  }
}
