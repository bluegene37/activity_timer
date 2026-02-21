import 'package:flutter/material.dart';
import 'dart:math' as math;

class GlowingTimerRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double size;
  final Widget child;

  const GlowingTimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 15.0,
    this.size = 250.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlowingRingPainter(
          progress: progress,
          color: color,
          backgroundColor: backgroundColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _GlowingRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _GlowingRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - (strokeWidth / 2);

    // Draw background ring
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Draw glowing shadow
    final shadowPaint =
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, shadowPaint);

    // Draw foreground ring
    final fgPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
