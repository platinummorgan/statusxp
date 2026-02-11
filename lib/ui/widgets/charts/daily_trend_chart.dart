import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:statusxp/theme/colors.dart';

/// Compact 30-day daily activity chart with platform stacking.
class DailyTrendChart extends StatelessWidget {
  final DailyTrendData data;

  const DailyTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No recent activity data',
            style: TextStyle(color: textMuted),
          ),
        ),
      );
    }

    final maxTotal = data.points
        .map((point) => point.totalCount)
        .fold<int>(0, (max, value) => value > max ? value : max);

    final safeMax = maxTotal <= 0 ? 1 : maxTotal;
    final lastPoint = data.points.last;
    final previousPoint = data.points.length > 1
        ? data.points[data.points.length - 2]
        : null;
    final trendDelta = lastPoint.totalCount - (previousPoint?.totalCount ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _legendDot('PSN', const Color(0xFF0070CC)),
            _legendDot('Xbox', const Color(0xFF107C10)),
            _legendDot('Steam', Colors.white70),
            Text(
              '7d: ${data.totalLast7Days}  ·  30d: ${data.totalLast30Days}',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
            Text(
              trendDelta >= 0
                  ? '+$trendDelta vs yesterday'
                  : '$trendDelta vs yesterday',
              style: TextStyle(
                color: trendDelta >= 0 ? accentSuccess : Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.points.map((point) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _stackedBar(point, safeMax),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _stackedBar(DailyTrendPoint point, int maxTotal) {
    final total = point.totalCount;
    if (total <= 0) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final ratio = total / maxTotal;
    final height = (ratio * 150).clamp(6, 150).toDouble();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Tooltip(
        message:
            '${point.date.month}/${point.date.day} · PSN ${point.psnCount}, Xbox ${point.xboxCount}, Steam ${point.steamCount}',
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              if (point.steamCount > 0)
                Expanded(
                  flex: point.steamCount,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              if (point.xboxCount > 0)
                Expanded(
                  flex: point.xboxCount,
                  child: Container(color: const Color(0xFF107C10)),
                ),
              if (point.psnCount > 0)
                Expanded(
                  flex: point.psnCount,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0070CC),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }
}
