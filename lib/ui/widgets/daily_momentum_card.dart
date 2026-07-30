import 'package:flutter/material.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class DailyMomentumCard extends StatelessWidget {
  const DailyMomentumCard({
    required this.snapshot,
    required this.onTap,
    super.key,
  });

  final EngagementSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final daily =
        snapshot.challenges
            .where((challenge) => challenge.periodType == 'daily')
            .toList()
          ..sort((a, b) {
            final aRank = a.claimable ? 0 : (a.claimed ? 2 : 1);
            final bRank = b.claimable ? 0 : (b.claimed ? 2 : 1);
            return aRank.compareTo(bRank);
          });
    if (daily.isEmpty) return const SizedBox.shrink();

    final challenge = daily.first;
    final complete = daily.every((item) => item.completed || item.claimed);
    final color = challenge.claimable || complete
        ? CyberpunkTheme.neonGreen
        : CyberpunkTheme.neonCyan;
    final title = challenge.claimable
        ? '+${challenge.rewardXp} StatusXP ready to claim'
        : complete
        ? 'Today complete — streak protected'
        : challenge.title;

    return Semantics(
      button: true,
      label: 'Today: $title',
      child: Material(
        color: const Color(0xFF0A0E27).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Row(
              children: [
                Icon(
                  complete ? Icons.check_circle : Icons.bolt,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!complete) ...[
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: challenge.progressFraction,
                          minHeight: 4,
                          color: color,
                          backgroundColor: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  challenge.claimable
                      ? 'CLAIM'
                      : '${challenge.progress}/${challenge.target}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
