import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';

/// Trophy type breakdown chart (PSN)
class TrophyTypeChart extends StatelessWidget {
  final TrophyTypeBreakdown data;

  const TrophyTypeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.total == 0) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          if (data.bronze > 0)
            Expanded(
              child: _buildTypeBar(
                'Bronze',
                data.bronze,
                data.bronzePercent,
                const Color(0xFFCD7F32),
              ),
            ),
          if (data.silver > 0)
            Expanded(
              child: _buildTypeBar(
                'Silver',
                data.silver,
                data.silverPercent,
                const Color(0xFFC0C0C0),
              ),
            ),
          if (data.gold > 0)
            Expanded(
              child: _buildTypeBar(
                'Gold',
                data.gold,
                data.goldPercent,
                const Color(0xFFFFD700),
              ),
            ),
          if (data.platinum > 0)
            Expanded(
              child: _buildTypeBar(
                'Platinum',
                data.platinum,
                data.platinumPercent,
                const Color(0xFF00D4FF),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'No PSN trophy data',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBar(String label, int count, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
