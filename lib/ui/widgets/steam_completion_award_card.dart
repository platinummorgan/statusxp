import 'package:flutter/material.dart';

class SteamCompletionAwardCard extends StatelessWidget {
  const SteamCompletionAwardCard({
    required this.points,
    this.estimatedRarity,
    this.allAchievements = false,
    super.key,
  });
  final double? points;
  final double? estimatedRarity;
  final bool allAchievements;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: ListTile(
      leading: const Icon(Icons.verified_outlined, color: Color(0xFF66C0F4)),
      title: Text(
        '${allAchievements ? "All Achievements 100%" : "Base Game 100%"} · '
        '${points == null ? "StatusXP unavailable" : "${points!.toStringAsFixed(2)} StatusXP"}',
      ),
      subtitle: Text(
        estimatedRarity == null
            ? 'All required achievements earned. Estimated rarity unavailable.'
            : 'Estimated rarity: ${estimatedRarity!.toStringAsFixed(2)}%\n'
                  'Lowest required achievement rarity · 1× rarity weighting',
      ),
    ),
  );
}
