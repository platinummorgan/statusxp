import 'package:flutter/material.dart';
import 'package:statusxp/data/sample_data.dart';
import 'package:statusxp/ui/widgets/game_list_tile.dart';

/// Games List Screen
/// 
/// Displays all tracked games with trophy progress.
/// Shows completion percentage and platinum indicators.
class GamesListScreen extends StatelessWidget {
  const GamesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sampleGames.length} Games Tracked',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${sampleGames.where((g) => g.hasPlatinum).length} Platinums Earned',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Games list
          Expanded(
            child: ListView.builder(
              itemCount: sampleGames.length,
              itemBuilder: (context, index) {
                final game = sampleGames[index];
                return GameListTile(game: game);
              },
            ),
          ),
        ],
      ),
    );
  }
}
