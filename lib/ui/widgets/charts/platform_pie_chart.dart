import 'dart:math';
import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';

/// Platform distribution pie chart
class PlatformPieChart extends StatelessWidget {
  final PlatformDistribution data;

  const PlatformPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.total == 0) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 250,
      child: Row(
        children: [
          // Pie chart
          Expanded(
            flex: 2,
            child: CustomPaint(
              painter: _PieChartPainter(data),
              child: Container(),
            ),
          ),
          // Legend
          Expanded(
            flex: 1,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'No platform data',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.psnCount > 0)
          _buildLegendItem('PSN', data.psnCount, data.psnPercent, const Color(0xFF0070CC)),
        if (data.xboxCount > 0)
          _buildLegendItem('Xbox', data.xboxCount, data.xboxPercent, const Color(0xFF107C10)),
        if (data.steamCount > 0)
          _buildLegendItem('Steam', data.steamCount, data.steamPercent, const Color(0xFF66C0F4)),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count (${percent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final PlatformDistribution data;

  _PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.7;

    double startAngle = -pi / 2; // Start at top

    // PSN
    if (data.psnCount > 0) {
      final sweepAngle = (data.psnCount / data.total) * 2 * pi;
      final paint = Paint()
        ..color = const Color(0xFF0070CC)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Xbox
    if (data.xboxCount > 0) {
      final sweepAngle = (data.xboxCount / data.total) * 2 * pi;
      final paint = Paint()
        ..color = const Color(0xFF107C10)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Steam
    if (data.steamCount > 0) {
      final sweepAngle = (data.steamCount / data.total) * 2 * pi;
      final paint = Paint()
        ..color = const Color(0xFF66C0F4)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = const Color(0xFF1a1f2e)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);

    // Draw total in center
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: data.total.toString(), style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
