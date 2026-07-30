import 'package:flutter/material.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class DashboardBackgroundGameGrid extends StatelessWidget {
  const DashboardBackgroundGameGrid({
    required this.games,
    required this.selectedTitle,
    required this.onSelected,
    super.key,
  });

  final List<UnifiedGame> games;
  final String? selectedTitle;
  final ValueChanged<UnifiedGame> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ((games.length / 3).ceil() * 182.0) + 20,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          final isSelected = game.title == selectedTitle;

          return GestureDetector(
            onTap: () => onSelected(game),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? CyberpunkTheme.neonPurple
                      : Colors.white.withValues(alpha: 0.2),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CyberpunkTheme.neonPurple.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _GameCover(url: game.coverUrl),
                    if (isSelected)
                      ColoredBox(
                        color: CyberpunkTheme.neonPurple.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameCover extends StatelessWidget {
  const _GameCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ColoredBox(
        color: Colors.grey.shade900,
        child: const Icon(Icons.videogame_asset, color: Colors.grey),
      );
    }

    return Image.network(
      url!,
      cacheWidth: 360,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Colors.grey.shade900,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
