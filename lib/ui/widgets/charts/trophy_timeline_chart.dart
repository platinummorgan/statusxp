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
    if (data.psnPoints.isEmpty &&
        data.xboxPoints.isEmpty &&
        data.steamPoints.isEmpty) {
      return _buildEmptyState();
    }

    final rangeFormat = DateFormat('MMM d, yyyy');
    DateTime? startDate;
    DateTime? endDate;
    if (data.firstTrophy != null && data.lastTrophy != null) {
      startDate = data.firstTrophy!.isBefore(data.lastTrophy!)
          ? data.firstTrophy!
          : data.lastTrophy!;
      endDate = data.firstTrophy!.isAfter(data.lastTrophy!)
          ? data.firstTrophy!
          : data.lastTrophy!;
    }
    final rangeText = (startDate != null && endDate != null)
        ? 'Cumulative totals from ${rangeFormat.format(startDate)} to ${rangeFormat.format(endDate)}'
        : 'Cumulative totals over time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _TimelineLegendDot(label: 'PSN', color: Color(0xFF0070CC)),
            _TimelineLegendDot(label: 'Xbox', color: Color(0xFF107C10)),
            _TimelineLegendDot(label: 'Steam', color: Colors.white70),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _TimelineChartPainter(data),
            child: Container(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rangeText,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            Text('No trophy data yet', style: TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _TimelineChartPainter extends CustomPainter {
  final TrophyTimelineData data;
  static const double _xAxisLabelBandHeight = 18;

  _TimelineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Get all points to calculate scale
    final allPoints = [
      ...data.psnPoints,
      ...data.xboxPoints,
      ...data.steamPoints,
    ];
    if (allPoints.isEmpty) return;

    // Calculate scales based on all data
    final maxCount = allPoints
        .map((p) => p.cumulativeCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final allDates = allPoints
        .map((p) => p.date.millisecondsSinceEpoch)
        .toList();
    final minDate = allDates.reduce((a, b) => a < b ? a : b).toDouble();
    final maxDate = allDates.reduce((a, b) => a > b ? a : b).toDouble();
    final dateRange = (maxDate - minDate) == 0 ? 1.0 : (maxDate - minDate);

    // Reserve space for X-axis labels so they don't overlap footer text.
    final chartHeight = (size.height - _xAxisLabelBandHeight).clamp(
      80.0,
      size.height,
    );
    final chartSize = Size(size.width, chartHeight);

    // Draw grid lines
    _drawGrid(canvas, chartSize);

    // Draw PSN line (blue)
    if (data.psnPoints.isNotEmpty) {
      _drawLine(
        canvas,
        size,
        chartSize,
        data.psnPoints,
        const Color(0xFF0070CC),
        minDate,
        dateRange,
        maxCount,
      );
    }

    // Draw Xbox line (green)
    if (data.xboxPoints.isNotEmpty) {
      _drawLine(
        canvas,
        size,
        chartSize,
        data.xboxPoints,
        const Color(0xFF107C10),
        minDate,
        dateRange,
        maxCount,
      );
    }

    // Draw Steam line (white)
    if (data.steamPoints.isNotEmpty) {
      _drawLine(
        canvas,
        size,
        chartSize,
        data.steamPoints,
        Colors.white,
        minDate,
        dateRange,
        maxCount,
      );
    }

    // Draw labels
    _drawLabels(canvas, chartSize, maxCount.toInt());
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    Size chartSize,
    List<TimelinePoint> points,
    Color color,
    double minDate,
    double dateRange,
    double maxCount,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x =
          ((point.date.millisecondsSinceEpoch - minDate) / dateRange) *
          chartSize.width;
      final y =
          chartSize.height -
          ((point.cumulativeCount / maxCount) * chartSize.height);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(linePath, paint);
  }

  void _drawGrid(Canvas canvas, Size chartSize) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = (chartSize.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(chartSize.width, y), gridPaint);
    }
  }

  void _drawLabels(Canvas canvas, Size chartSize, int maxCount) {
    final textStyle = TextStyle(color: Colors.grey[600], fontSize: 10);

    // Y-axis labels (count)
    for (int i = 0; i <= 4; i++) {
      final value = (maxCount / 4 * i).round();
      final textSpan = TextSpan(text: value.toString(), style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      final y =
          chartSize.height -
          (chartSize.height / 4 * i) -
          (textPainter.height / 2);
      textPainter.paint(canvas, Offset(-textPainter.width - 4, y));
    }

    // X-axis labels (dates)
    if (data.firstTrophy != null && data.lastTrophy != null) {
      final orderedStart = data.firstTrophy!.isBefore(data.lastTrophy!)
          ? data.firstTrophy!
          : data.lastTrophy!;
      final orderedEnd = data.firstTrophy!.isAfter(data.lastTrophy!)
          ? data.firstTrophy!
          : data.lastTrophy!;
      final dateFormat = DateFormat('MMM yyyy');

      // Start date
      final startText = TextSpan(
        text: dateFormat.format(orderedStart),
        style: textStyle,
      );
      final startPainter = TextPainter(
        text: startText,
        textDirection: ui.TextDirection.ltr,
      );
      startPainter.layout();
      startPainter.paint(canvas, Offset(0, chartSize.height + 4));

      // End date
      final endText = TextSpan(
        text: dateFormat.format(orderedEnd),
        style: textStyle,
      );
      final endPainter = TextPainter(
        text: endText,
        textDirection: ui.TextDirection.ltr,
      );
      endPainter.layout();
      endPainter.paint(
        canvas,
        Offset(chartSize.width - endPainter.width, chartSize.height + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TimelineLegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _TimelineLegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
