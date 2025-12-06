import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/models/display_case_item.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// PlayStation symbol-shaped frames for rarity showcase
enum PSSymbol { triangle, circle, cross, square }

class PSSymbolFrame extends StatelessWidget {
  final DisplayCaseItem item;
  final DisplayCaseTheme theme;
  final PSSymbol symbol;
  final String label; // "Rarest", "Rarest Silver", etc.
  final VoidCallback? onTap;

  const PSSymbolFrame({
    super.key,
    required this.item,
    required this.theme,
    required this.symbol,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _PSSymbolPainter(
                symbol: symbol,
                color: theme.getTierColor(item.tier),
              ),
              child: Center(
                child: Image.network(
                  item.iconUrl ?? '',
                  width: 50,
                  height: 50,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.emoji_events, size: 50, color: Colors.white);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PSSymbolPainter extends CustomPainter {
  final PSSymbol symbol;
  final Color color;

  _PSSymbolPainter({required this.symbol, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Get neon color based on symbol
    final neonColor = _getNeonColor(symbol);
    
    final paint = Paint()
      ..color = neonColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = neonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    // Add outer glow effect
    final glowPaint = Paint()
      ..color = neonColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final center = Offset(size.width / 2, size.height / 2);

    switch (symbol) {
      case PSSymbol.triangle:
        _drawTriangle(canvas, size, paint, borderPaint, glowPaint);
        break;
      case PSSymbol.circle:
        _drawCircle(canvas, center, size, paint, borderPaint, glowPaint);
        break;
      case PSSymbol.cross:
        _drawCross(canvas, center, size, borderPaint, glowPaint);
        break;
      case PSSymbol.square:
        _drawSquare(canvas, size, paint, borderPaint, glowPaint);
        break;
    }
  }

  Color _getNeonColor(PSSymbol symbol) {
    switch (symbol) {
      case PSSymbol.triangle:
        return const Color(0xFF00FF00); // Neon Green
      case PSSymbol.square:
        return const Color(0xFFFF1493); // Neon Pink
      case PSSymbol.circle:
        return const Color(0xFFFF0000); // Neon Red
      case PSSymbol.cross:
        return const Color(0xFF00BFFF); // Neon Blue
    }
  }

  void _drawTriangle(Canvas canvas, Size size, Paint paint, Paint borderPaint, Paint glowPaint) {
    final path = Path();
    path.moveTo(size.width / 2, 5); // Top point
    path.lineTo(5, size.height - 5); // Bottom left
    path.lineTo(size.width - 5, size.height - 5); // Bottom right
    path.close();

    canvas.drawPath(path, glowPaint); // Draw glow
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawCircle(Canvas canvas, Offset center, Size size, Paint paint, Paint borderPaint, Paint glowPaint) {
    final radius = (size.width / 2) - 5;
    canvas.drawCircle(center, radius, glowPaint); // Draw glow
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawCross(Canvas canvas, Offset center, Size size, Paint borderPaint, Paint glowPaint) {
    // Draw X shape with no circle - just the X itself
    final crossPaint = Paint()
      ..color = borderPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    
    final crossGlowPaint = Paint()
      ..color = glowPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    const inset = 12.0;
    
    // Draw glow first
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      crossGlowPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      crossGlowPaint,
    );
    
    // Draw X on top
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      crossPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      crossPaint,
    );
  }

  void _drawSquare(Canvas canvas, Size size, Paint paint, Paint borderPaint, Paint glowPaint) {
    final rect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    canvas.drawRect(rect, glowPaint); // Draw glow
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for empty symbol slots
class EmptySymbolPainter extends CustomPainter {
  final PSSymbol symbol;

  EmptySymbolPainter({required this.symbol});

  @override
  void paint(Canvas canvas, Size size) {
    // Get neon color based on symbol
    final neonColor = _getNeonColor(symbol);
    
    final borderPaint = Paint()
      ..color = neonColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Subtle glow for empty state
    final glowPaint = Paint()
      ..color = neonColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final center = Offset(size.width / 2, size.height / 2);

    switch (symbol) {
      case PSSymbol.triangle:
        _drawTriangle(canvas, size, borderPaint, glowPaint);
        break;
      case PSSymbol.circle:
        _drawCircle(canvas, center, size, borderPaint, glowPaint);
        break;
      case PSSymbol.cross:
        _drawCross(canvas, center, size, borderPaint, glowPaint);
        break;
      case PSSymbol.square:
        _drawSquare(canvas, size, borderPaint, glowPaint);
        break;
    }
  }

  Color _getNeonColor(PSSymbol symbol) {
    switch (symbol) {
      case PSSymbol.triangle:
        return const Color(0xFF00FF00); // Neon Green
      case PSSymbol.square:
        return const Color(0xFFFF1493); // Neon Pink
      case PSSymbol.circle:
        return const Color(0xFFFF0000); // Neon Red
      case PSSymbol.cross:
        return const Color(0xFF00BFFF); // Neon Blue
    }
  }

  void _drawTriangle(Canvas canvas, Size size, Paint borderPaint, Paint glowPaint) {
    final path = Path();
    path.moveTo(size.width / 2, 5);
    path.lineTo(5, size.height - 5);
    path.lineTo(size.width - 5, size.height - 5);
    path.close();
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawCircle(Canvas canvas, Offset center, Size size, Paint borderPaint, Paint glowPaint) {
    final radius = (size.width / 2) - 5;
    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawCross(Canvas canvas, Offset center, Size size, Paint borderPaint, Paint glowPaint) {
    final crossPaint = Paint()
      ..color = borderPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final crossGlowPaint = Paint()
      ..color = glowPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    const inset = 12.0;
    
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      crossGlowPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      crossGlowPaint,
    );
    
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      crossPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      crossPaint,
    );
  }

  void _drawSquare(Canvas canvas, Size size, Paint borderPaint, Paint glowPaint) {
    final rect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    canvas.drawRect(rect, glowPaint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
