import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Neon circular progress ring with glowing effect
/// 
/// Displays a circular progress indicator with cyberpunk neon styling.
/// Used for showing platinum trophy count and completion rate.
class NeonRing extends StatefulWidget {
  final int value;
  final String label;
  final double progress; // 0.0 to 1.0
  final Color color;
  final double size;
  final String? subtitle;
  
  const NeonRing({
    super.key,
    required this.value,
    required this.label,
    required this.progress,
    this.color = CyberpunkTheme.neonCyan,
    this.size = 200,
    this.subtitle,
  });
  
  @override
  State<NeonRing> createState() => _NeonRingState();
}

class _NeonRingState extends State<NeonRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring (dim)
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RingPainter(
                progress: 1.0,
                color: widget.color.withOpacity(0.12),
                strokeWidth: 12,
              ),
            ),
          ),
          
          // Animated progress ring with enhanced glow
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4 * _pulseAnimation.value),
                      blurRadius: 40 * _pulseAnimation.value,
                      spreadRadius: 12 * _pulseAnimation.value,
                    ),
                    BoxShadow(
                      color: widget.color.withOpacity(0.2),
                      blurRadius: 60,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: widget.progress,
                    color: widget.color,
                    strokeWidth: 12,
                  ),
                ),
              );
            },
          ),
          
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.value.toString(),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: widget.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 68,
                  height: 0.95,
                  shadows: [
                    ...CyberpunkTheme.neonGlow(color: widget.color, blurRadius: 12),
                    Shadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 2.5,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.color.withOpacity(0.85),
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the circular ring
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    const startAngle = -math.pi / 2; // Start at top
    final sweepAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
