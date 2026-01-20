import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:statusxp/theme/colors.dart';

/// Monthly activity bar chart
class MonthlyActivityChart extends StatelessWidget {
  final MonthlyActivity data;

  const MonthlyActivityChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.months.isEmpty) {
      return _buildEmptyState();
    }

    final maxCount = data.months.map((m) => m.totalCount).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.months.map((month) {
                return Expanded(
                  child: _buildStackedBar(month, maxCount),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'No activity data',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedBar(MonthlyDataPoint month, int maxCount) {
    final totalHeight = month.totalCount / maxCount;
    final isMostActive = month.totalCount == maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Always show total count
          Text(
            month.totalCount.toString(),
            style: TextStyle(
              color: isMostActive ? accentPrimary : Colors.grey[500],
              fontSize: data.months.length > 6 ? 9 : 11,
              fontWeight: isMostActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          // Stacked bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barHeight = constraints.maxHeight * totalHeight;
                final psnHeight = month.psnCount / month.totalCount * barHeight;
                final xboxHeight = month.xboxCount / month.totalCount * barHeight;
                final steamHeight = month.steamCount / month.totalCount * barHeight;
                
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    height: barHeight,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Steam (top - white)
                        if (month.steamCount > 0)
                          Expanded(
                            flex: month.steamCount,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        // Xbox (middle - green)
                        if (month.xboxCount > 0)
                          Expanded(
                            flex: month.xboxCount,
                            child: Container(
                              color: const Color(0xFF107C10),
                            ),
                          ),
                        // PSN (bottom - blue)
                        if (month.psnCount > 0)
                          Expanded(
                            flex: month.psnCount,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0070CC),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(0),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Month label
          Text(
            month.label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}
