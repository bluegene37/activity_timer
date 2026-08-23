import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlowingTimerRing extends StatelessWidget {
  const GlowingTimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 16.0,
    this.size = 260.0,
    required this.child,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppleFitnessRingPainter(
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

class _AppleFitnessRingPainter extends CustomPainter {
  _AppleFitnessRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Draw Apple Background track (subtle translucent ring with rounded track)
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final clampedProgress = progress.clamp(0.0, 1.0);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * clampedProgress;

    // 2. Draw Apple Watch ambient neon glow
    final glowPaint =
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    // 3. Draw Gradient Arc (Apple Fitness style gradient from lighter to vibrant color)
    final HSLColor hsl = HSLColor.fromColor(color);
    final lightColor =
        hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    final deepColor = color;

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: [lightColor, deepColor],
      stops: const [0.0, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final fgPaint =
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);

    // 4. Draw Apple Activity Ring end-point shadow for authentic depth
    if (clampedProgress > 0.05) {
      final endAngle = startAngle + sweepAngle;
      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final endCapShadow =
          Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(endPoint, strokeWidth / 2, endCapShadow);

      // Re-draw crisp end point tip
      final endCapPaint =
          Paint()
            ..color = deepColor
            ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, strokeWidth / 2, endCapPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleFitnessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
