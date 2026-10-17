import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class DashboardGamesList extends StatelessWidget {
  const DashboardGamesList({
    required this.games,
    required this.gameBuilder,
    required this.onViewAll,
    super.key,
  });

  final AsyncValue<List<UnifiedGame>> games;
  final Widget Function(UnifiedGame game) gameBuilder;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return games.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.cloud_off_outlined, size: 36, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Your games are temporarily unavailable. Reconnecting automatically…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No games yet. Sync your platforms to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          );
        }

        return Column(
          children: [
            ...items.take(20).map(gameBuilder),
            if (items.length >= 20)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    items.length > 20
                        ? 'View All ${items.length} Games →'
                        : 'View All Games →',
                    style: const TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
