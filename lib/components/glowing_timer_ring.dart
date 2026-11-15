import 'dart:math' as math;
import 'package:flutter/material.dart';

// Gene - Nov, 16, 2026: Add optional secondaryProgress 60s pace ring and fix 12-o'clock sweep/lightness visibility for long (1h+) timers.
// class GlowingTimerRing extends StatelessWidget {
//   const GlowingTimerRing({
//     super.key,
//     required this.progress,
//     required this.color,
//     required this.backgroundColor,
//     this.strokeWidth = 16.0,
//     this.size = 260.0,
//     required this.child,
//   });
//
//   final double progress;
//   final Color color;
//   final Color backgroundColor;
//   final double strokeWidth;
//   final double size;
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: size,
//       height: size,
//       child: CustomPaint(
//         painter: _AppleFitnessRingPainter(
//           progress: progress,
//           color: color,
//           backgroundColor: backgroundColor,
//           strokeWidth: strokeWidth,
//         ),
//         child: Center(child: child),
//       ),
//     );
//   }
// }
//
// class _AppleFitnessRingPainter extends CustomPainter {
//   _AppleFitnessRingPainter({
//     required this.progress,
//     required this.color,
//     required this.backgroundColor,
//     required this.strokeWidth,
//   });
//
//   final double progress;
//   final Color color;
//   final Color backgroundColor;
//   final double strokeWidth;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = math.min(size.width, size.height) / 2 - (strokeWidth / 2);
//     final rect = Rect.fromCircle(center: center, radius: radius);
//
//     // 1. Draw Apple Background track (subtle translucent ring with rounded track)
//     final bgPaint =
//         Paint()
//           ..color = backgroundColor
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = strokeWidth
//           ..strokeCap = StrokeCap.round;
//
//     canvas.drawCircle(center, radius, bgPaint);
//
//     if (progress <= 0) return;
//
//     final clampedProgress = progress.clamp(0.0, 1.0);
//     const startAngle = -math.pi / 2;
//     final sweepAngle = 2 * math.pi * clampedProgress;
//
//     // 2. Draw Apple Watch ambient neon glow
//     final glowPaint =
//         Paint()
//           ..color = color.withValues(alpha: 0.35)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = strokeWidth * 1.4
//           ..strokeCap = StrokeCap.round
//           ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
//
//     canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
//
//     // 3. Draw Gradient Arc (Apple Fitness style gradient from lighter to vibrant color)
//     final HSLColor hsl = HSLColor.fromColor(color);
//     final lightColor =
//         hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
//     final deepColor = color;
//
//     final gradient = SweepGradient(
//       startAngle: 0.0,
//       endAngle: 2 * math.pi,
//       colors: [lightColor, deepColor],
//       stops: const [0.0, 1.0],
//       transform: const GradientRotation(-math.pi / 2),
//     );
//
//     final fgPaint =
//         Paint()
//           ..shader = gradient.createShader(rect)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = strokeWidth
//           ..strokeCap = StrokeCap.round;
//
//     canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
//
//     // 4. Draw Apple Activity Ring end-point shadow for authentic depth
//     if (clampedProgress > 0.05) {
//       final endAngle = startAngle + sweepAngle;
//       final endPoint = Offset(
//         center.dx + radius * math.cos(endAngle),
//         center.dy + radius * math.sin(endAngle),
//       );
//
//       final endCapShadow =
//           Paint()
//             ..color = Colors.black.withValues(alpha: 0.25)
//             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
//
//       canvas.drawCircle(endPoint, strokeWidth / 2, endCapShadow);
//
//       // Re-draw crisp end point tip
//       final endCapPaint =
//           Paint()
//             ..color = deepColor
//             ..style = PaintingStyle.fill;
//       canvas.drawCircle(endPoint, strokeWidth / 2, endCapPaint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant _AppleFitnessRingPainter oldDelegate) {
//     return oldDelegate.progress != progress ||
//         oldDelegate.color != color ||
//         oldDelegate.backgroundColor != backgroundColor ||
//         oldDelegate.strokeWidth != strokeWidth;
//   }
// }
class GlowingTimerRing extends StatelessWidget {
  const GlowingTimerRing({
    super.key,
    required this.progress,
    this.secondaryProgress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 16.0,
    this.size = 260.0,
    required this.child,
  });

  final double progress;
  final double? secondaryProgress;
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
          secondaryProgress: secondaryProgress,
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
    required this.secondaryProgress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final double? secondaryProgress;
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

    // Outer overall-progress ring
    if (progress > 0 || secondaryProgress != null) {
      final clampedProgress = progress.clamp(0.0, 1.0);
      const startAngle = -math.pi / 2;
      final sweepAngle =
          clampedProgress > 0
              ? math.max(2 * math.pi * clampedProgress, 0.035)
              : 0.025;

      // 2. Draw Apple Watch ambient neon glow
      final glowPaint =
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth * 1.4
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

      // 3. Draw Gradient Arc (offset rotation avoids 12-o'clock seam & washed start)
      final HSLColor hsl = HSLColor.fromColor(color);
      final lightColor =
          hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 0.72)).toColor();
      final deepColor = color;
      final endStop = (clampedProgress + 0.08).clamp(0.12, 0.98);

      final gradient = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [lightColor, deepColor, deepColor],
        stops: [0.0, endStop, 1.0],
        transform: const GradientRotation(-math.pi / 2 - 0.12),
      );

      final fgPaint =
          Paint()
            ..shader = gradient.createShader(rect)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);

      // 4. Draw Apple Activity Ring end-point shadow for authentic depth
      if (clampedProgress > 0.02) {
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

    // Inner concentric 60-second pace ring for multi-minute / hour+ timers
    if (secondaryProgress != null) {
      final innerStroke = (strokeWidth * 0.30).clamp(3.5, 5.5);
      final innerGap = (strokeWidth * 0.28).clamp(3.0, 5.5);
      final innerRadius =
          radius - (strokeWidth / 2) - innerGap - (innerStroke / 2);
      if (innerRadius > innerStroke * 2) {
        final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
        final innerBgPaint =
            Paint()
              ..color = backgroundColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = innerStroke
              ..strokeCap = StrokeCap.round;
        canvas.drawCircle(center, innerRadius, innerBgPaint);

        final secClamped = secondaryProgress!.clamp(0.0, 1.0);
        const startAngle = -math.pi / 2;
        if (secClamped > 0) {
          final secSweep = math.max(2 * math.pi * secClamped, 0.04);
          final innerGlow =
              Paint()
                ..color = color.withValues(alpha: 0.25)
                ..style = PaintingStyle.stroke
                ..strokeWidth = innerStroke * 1.4
                ..strokeCap = StrokeCap.round
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawArc(innerRect, startAngle, secSweep, false, innerGlow);

          final innerFg =
              Paint()
                ..color = color.withValues(alpha: 0.90)
                ..style = PaintingStyle.stroke
                ..strokeWidth = innerStroke
                ..strokeCap = StrokeCap.round;
          canvas.drawArc(innerRect, startAngle, secSweep, false, innerFg);
        }

        // Crisp leading pace bead orbiting once every 60 seconds
        final beadAngle = startAngle + (2 * math.pi * secClamped);
        final beadPoint = Offset(
          center.dx + innerRadius * math.cos(beadAngle),
          center.dy + innerRadius * math.sin(beadAngle),
        );
        final beadPaint =
            Paint()
              ..color = color
              ..style = PaintingStyle.fill;
        canvas.drawCircle(beadPoint, innerStroke * 0.62, beadPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AppleFitnessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.secondaryProgress != secondaryProgress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
