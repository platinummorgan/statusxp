import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:intl/intl.dart';

/// Trophy timeline chart - shows cumulative trophy growth over time
class TrophyTimelineChart extends StatelessWidget {
  final TrophyTimelineData data;

  const TrophyTimelineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.psnPoints.isEmpty && data.xboxPoints.isEmpty && data.steamPoints.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _TimelineChartPainter(data),
        child: Container(),
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
            Icon(Icons.timeline, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text(
              'No trophy data yet',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineChartPainter extends CustomPainter {
  final TrophyTimelineData data;

  _TimelineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Get all points to calculate scale
    final allPoints = [...data.psnPoints, ...data.xboxPoints, ...data.steamPoints];
    if (allPoints.isEmpty) return;

    // Calculate scales based on all data
    final maxCount = allPoints.map((p) => p.cumulativeCount).reduce((a, b) => a > b ? a : b).toDouble();
    final allDates = allPoints.map((p) => p.date.millisecondsSinceEpoch).toList();
    final minDate = allDates.reduce((a, b) => a < b ? a : b).toDouble();
    final maxDate = allDates.reduce((a, b) => a > b ? a : b).toDouble();

    // Draw grid lines
    _drawGrid(canvas, size);

    // Draw PSN line (blue)
    if (data.psnPoints.isNotEmpty) {
      _drawLine(canvas, size, data.psnPoints, const Color(0xFF0070CC), minDate, maxDate, maxCount);
    }

    // Draw Xbox line (green)
    if (data.xboxPoints.isNotEmpty) {
      _drawLine(canvas, size, data.xboxPoints, const Color(0xFF107C10), minDate, maxDate, maxCount);
    }

    // Draw Steam line (white)
    if (data.steamPoints.isNotEmpty) {
      _drawLine(canvas, size, data.steamPoints, Colors.white, minDate, maxDate, maxCount);
    }

    // Draw labels
    _drawLabels(canvas, size, maxCount.toInt());
  }

  void _drawLine(Canvas canvas, Size size, List<TimelinePoint> points, Color color, double minDate, double maxDate, double maxCount) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = ((point.date.millisecondsSinceEpoch - minDate) / (maxDate - minDate)) * size.width;
      final y = size.height - ((point.cumulativeCount / maxCount) * size.height);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(linePath, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _drawLabels(Canvas canvas, Size size, int maxCount) {
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
    );

    // Y-axis labels (count)
    for (int i = 0; i <= 4; i++) {
      final value = (maxCount / 4 * i).round();
      final textSpan = TextSpan(text: value.toString(), style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      final y = size.height - (size.height / 4 * i) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(-textPainter.width - 4, y));
    }

    // X-axis labels (dates)
    if (data.firstTrophy != null && data.lastTrophy != null) {
      final dateFormat = DateFormat('MMM yy');
      
      // Start date
      final startText = TextSpan(text: dateFormat.format(data.firstTrophy!), style: textStyle);
      final startPainter = TextPainter(text: startText, textDirection: ui.TextDirection.ltr);
      startPainter.layout();
      startPainter.paint(canvas, Offset(0, size.height + 4));

      // End date
      final endText = TextSpan(text: dateFormat.format(data.lastTrophy!), style: textStyle);
      final endPainter = TextPainter(text: endText, textDirection: ui.TextDirection.ltr);
      endPainter.layout();
      endPainter.paint(canvas, Offset(size.width - endPainter.width, size.height + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
