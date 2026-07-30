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
    return Row(
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
          label: 'Xbox Gamerscore',
          value: stats.xboxStats.gamerscore.toString(),
          subtitle: '${stats.xboxStats.gamesCount} Games',
          bottomLabel:
              '${stats.xboxStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF107C10),
        ),
        circleBuilder(
          label: 'Steam Achievs',
          value: stats.steamStats.achievementsUnlocked.toString(),
          subtitle: '${stats.steamStats.gamesCount} Games',
          bottomLabel:
              '${stats.steamStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF66C0F4),
        ),
      ],
    );
  }
}
