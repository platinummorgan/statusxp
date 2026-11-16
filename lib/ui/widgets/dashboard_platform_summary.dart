import 'package:flutter/material.dart';
import 'package:statusxp/domain/dashboard_stats.dart';

typedef PlatformCircleBuilder =
    Widget Function({
      required String label,
      required String value,
      required String subtitle,
      required String bottomLabel,
      required Color color,
    });

class DashboardPlatformSummary extends StatelessWidget {
  const DashboardPlatformSummary({
    required this.stats,
    required this.circleBuilder,
    super.key,
  });

  final DashboardStats stats;
  final PlatformCircleBuilder circleBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Tooltip(
          message:
              'Platinums + Xbox Mythics + Steam completions. '
              'Games awaiting a completion sync are not included.',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Total Completions: ${stats.totalCompletions}${stats.completionCountsPending ? " · verified so far" : ""}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            circleBuilder(
              label: 'Platinums',
              value: stats.psnStats.platinums.toString(),
              subtitle: '${stats.psnStats.gamesCount} Games',
              bottomLabel:
                  '${stats.psnStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
              color: const Color(0xFF00A8E1),
            ),
            circleBuilder(
              label: 'Xbox Mythics',
              value: stats.xboxStats.mythics?.toString() ?? '—',
              subtitle: '${stats.xboxStats.gamesCount} Games',
              bottomLabel: stats.xboxStats.mythics == null
                  ? 'SYNC XBOX'
                  : '${stats.xboxStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
              color: const Color(0xFF107C10),
            ),
            Tooltip(
              message:
                  'Complete the verified Steam base-game set, or all available achievements when the base set cannot be separated.',
              child: circleBuilder(
                label: 'Steam Completions',
                value: stats.steamStats.completions?.toString() ?? '—',
                subtitle: '${stats.steamStats.gamesCount} Games',
                bottomLabel: stats.steamStats.completions == null
                    ? 'SYNC STEAM'
                    : stats.steamStats.pendingCompletionReviews > 0
                    ? '${stats.steamStats.pendingCompletionReviews} AWAITING SYNC'
                    : 'GAME COMPLETIONS',
                color: const Color(0xFF66C0F4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
