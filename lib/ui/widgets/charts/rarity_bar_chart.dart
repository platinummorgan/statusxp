import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:statusxp/theme/colors.dart';

/// Rarity distribution bar chart
class RarityBarChart extends StatelessWidget {
  final RarityDistribution data;

  const RarityBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.total == 0) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (data.ultraRare > 0)
                  Expanded(
                    child: _buildBar(
                      'Ultra\nRare',
                      data.ultraRare,
                      data.ultraRarePercent,
                      data.total,
                      const Color(0xFFFF0080),
                    ),
                  ),
                if (data.veryRare > 0)
                  Expanded(
                    child: _buildBar(
                      'Very\nRare',
                      data.veryRare,
                      data.veryRarePercent,
                      data.total,
                      const Color(0xFFFF6B00),
                    ),
                  ),
                if (data.rare > 0)
                  Expanded(
                    child: _buildBar(
                      'Rare',
                      data.rare,
                      data.rarePercent,
                      data.total,
                      const Color(0xFFFFD700),
                    ),
                  ),
                if (data.uncommon > 0)
                  Expanded(
                    child: _buildBar(
                      'Uncommon',
                      data.uncommon,
                      data.uncommonPercent,
                      data.total,
                      accentSecondary,
                    ),
                  ),
                if (data.common > 0)
                  Expanded(
                    child: _buildBar(
                      'Common',
                      data.common,
                      data.commonPercent,
                      data.total,
                      Colors.blue,
                    ),
                  ),
                if (data.veryCommon > 0)
                  Expanded(
                    child: _buildBar(
                      'Very\nCommon',
                      data.veryCommon,
                      data.veryCommonPercent,
                      data.total,
                      Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'No rarity data',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String label, int count, double percent, int max, Color color) {
    final heightPercent = count / max;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Count
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Percentage
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          // Bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    height: constraints.maxHeight * heightPercent,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.6),
                          color,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Label
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
