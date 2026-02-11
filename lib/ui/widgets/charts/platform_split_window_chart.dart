import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:statusxp/theme/colors.dart';

/// Shows platform split for 7-day and 30-day windows.
class PlatformSplitWindowChart extends StatelessWidget {
  final PlatformSplitTrend data;

  const PlatformSplitWindowChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _windowRow('Last 7 Days', data.last7Days),
        const SizedBox(height: 12),
        _windowRow('Last 30 Days', data.last30Days),
      ],
    );
  }

  Widget _windowRow(String label, PlatformDistribution dist) {
    final total = dist.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$total total',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                _segment(const Color(0xFF0070CC), dist.psnCount, total),
                _segment(const Color(0xFF107C10), dist.xboxCount, total),
                _segment(Colors.white70, dist.steamCount, total),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legend(
              'PSN',
              dist.psnCount,
              dist.psnPercent,
              const Color(0xFF0070CC),
            ),
            _legend(
              'Xbox',
              dist.xboxCount,
              dist.xboxPercent,
              const Color(0xFF107C10),
            ),
            _legend(
              'Steam',
              dist.steamCount,
              dist.steamPercent,
              Colors.white70,
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment(Color color, int value, int total) {
    if (total <= 0 || value <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: value,
      child: Container(color: color),
    );
  }

  Widget _legend(String label, int count, double percent, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $count (${percent.toStringAsFixed(0)}%)',
          style: const TextStyle(color: textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
