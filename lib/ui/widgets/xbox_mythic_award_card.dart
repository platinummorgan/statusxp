import 'package:flutter/material.dart';

class XboxMythicAwardCard extends StatelessWidget {
  const XboxMythicAwardCard({
    required this.points,
    this.estimatedRarity,
    super.key,
  });

  final double points;
  final double? estimatedRarity;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: ListTile(
      leading: const Icon(Icons.diamond_outlined, color: Color(0xFF107C10)),
      title: Text('Mythic earned · ${points.toStringAsFixed(2)} StatusXP'),
      subtitle: Text(
        estimatedRarity == null
            ? 'Estimated rarity unavailable. Base-game rarity is still pending.'
            : 'Estimated rarity: ${estimatedRarity!.toStringAsFixed(2)}%\n'
                  'Lowest required base-game achievement rarity · 5× rarity weighting',
      ),
    ),
  );
}
