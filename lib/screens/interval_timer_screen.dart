import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../components/glowing_timer_ring.dart';
import '../controllers/interval_run_controller.dart';
import '../models/interval_timer.dart';
import '../models/settings.dart';
import '../services/interval_session_service.dart';
import '../theme/app_theme.dart';

class IntervalTimerScreen extends StatefulWidget {
  const IntervalTimerScreen({super.key, required this.timer, this.controller});

  final IntervalTimer timer;

  /// Test seam: production borrows the controller from
  /// [IntervalSessionService].
  final IntervalRunController? controller;

  @override
  State<IntervalTimerScreen> createState() => _IntervalTimerScreenState();
}

class _IntervalTimerScreenState extends State<IntervalTimerScreen> {
  // The session service owns the production controller, so popping this
  // screen minimizes a running schedule instead of killing it. The engine —
  // schedule normalization, ticking, alarms — lives in the controller.
  late final IntervalRunController _c =
      widget.controller ?? IntervalSessionService().obtain(widget.timer);
  final _settings = AppSettings();

  Color _getTimerColor(double progress, ColorScheme colorScheme) {
    final baseColor = HSLColor.fromColor(colorScheme.primary);
    final targetLightness = (baseColor.lightness + 0.15 - progress * 0.3).clamp(
      0.2,
      0.8,
    );
    return baseColor.withLightness(targetLightness).toColor();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      // A running schedule survives the pop (the floater offers the way
      // back); a completed one has nothing to keep alive.
      IntervalSessionService().releaseIfIdle();
    }
    super.dispose();
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Exit Timer?'),
            content: const Text('Are you sure you want to exit this timer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  IntervalSessionService().clear(); // End the session
                  Navigator.pop(context); // Close timer screen
                },
                child: const Text('Exit'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final timeFormat = DateFormat('h:mm:ss a');
    final timeFormatShort = DateFormat('h:mm a');

    return Obx(
      () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.timer.name),
          centerTitle: true,
          // Popping minimizes: a running schedule keeps ticking in the
          // session service and the floating chip brings it back.
          leading: IconButton(
            icon: Icon(
              CupertinoIcons.chevron_down,
              color: colorScheme.onSurface,
              size: 22,
            ),
            tooltip: 'Minimize',
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Sound toggle button
            IconButton(
              icon: Icon(
                _settings.soundEnabled
                    ? CupertinoIcons.speaker_2_fill
                    : CupertinoIcons.speaker_slash_fill,
                color:
                    _settings.soundEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () async {
                unawaited(HapticFeedback.selectionClick());
                final bool newValue = !_settings.soundEnabled;
                await _settings.setSoundEnabled(newValue);
                setState(() {});
              },
              tooltip: _settings.soundEnabled ? 'Mute sound' : 'Enable sound',
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.xmark,
                color: colorScheme.onSurface,
                size: 20,
              ),
              tooltip: 'End timer',
              onPressed: () {
                if (_c.isCompleted.value) {
                  Navigator.pop(context);
                } else {
                  _confirmExit();
                }
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body:
            _c.isCompleted.value
                ? _buildCompletedView(textTheme, colorScheme, timeFormatShort)
                : _buildRunningView(
                  textTheme,
                  colorScheme,
                  timeFormat,
                  timeFormatShort,
                ),
      ),
    );
  }

  Widget _buildRunningView(
    TextTheme textTheme,
    ColorScheme colorScheme,
    DateFormat timeFormat,
    DateFormat timeFormatShort,
  ) {
    final timeDifference = _c.nextAlarmTime.value.difference(_c.currentTime.value);
    final hours = timeDifference.inHours;
    final minutes = timeDifference.inMinutes % 60;
    final seconds = timeDifference.inSeconds % 60;

    // Calculate progress for the current interval
    final totalSeconds = widget.timer.intervalInSeconds;
    final remainingSeconds = timeDifference.inSeconds;

    double progress =
        totalSeconds > 0 ? 1.0 - (remainingSeconds / totalSeconds) : 0.0;
    progress = progress.clamp(0.0, 1.0);

    return SafeArea(
      child: Column(
        children: [
          // Progress indicator (iOS Thin Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:
                  _c.allAlarmTimes.length > 1
                      ? (_c.currentAlarmIndex.value / (_c.allAlarmTimes.length - 1))
                          .clamp(0.0, 1.0)
                      : 0.0,
              minHeight: 4,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
              color: colorScheme.primary,
            ),
          ),

          // Timer info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              children: [
                Text(
                  'Current Time',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeFormat.format(_c.currentTime.value),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Alarm ${_c.currentAlarmIndex.value + 1} of ${_c.allAlarmTimes.length}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        CupertinoIcons.bell_fill,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.timer.alarmSound.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Next alarm countdown inside GlowingTimerRing
          Expanded(
            child: Center(
              child: GlowingTimerRing(
                progress: progress,
                color: _getTimerColor(progress, colorScheme),
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                size: 280,
                strokeWidth: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${hours > 0 ? '${hours.toString()}:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: hours > 0 ? 46 : 60,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'till next alarm',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alarm list (iOS Inset Timeline)
          Container(
            height: 130,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant, width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Alarm Schedule',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Next: ${timeFormatShort.format(_c.nextAlarmTime.value)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _c.allAlarmTimes.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final alarmTime = _c.allAlarmTimes[index];
                      final isCurrentAlarm = index == _c.currentAlarmIndex.value;
                      final isPastAlarm = index < _c.currentAlarmIndex.value;

                      return Container(
                        width: 78,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color:
                              isCurrentAlarm
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isCurrentAlarm
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                            width: isCurrentAlarm ? 1.5 : 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color:
                                    isCurrentAlarm
                                        ? colorScheme.primary
                                        : isPastAlarm
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeFormatShort.format(alarmTime),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isCurrentAlarm
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                color:
                                    isCurrentAlarm
                                        ? colorScheme.primary
                                        : isPastAlarm
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              isPastAlarm
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              size: 14,
                              color:
                                  isPastAlarm
                                      ? AppTheme.iosGreen
                                      : isCurrentAlarm
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.restart),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _c.reset();
                  },
                  iconSize: 24,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 24),
                FloatingActionButton.large(
                  heroTag: 'play_pause',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _c.toggle();
                  },
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: Icon(
                    _c.isRunning.value
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(CupertinoIcons.forward_fill),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _c.skipToNext();
                  },
                  iconSize: 24,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(
    TextTheme textTheme,
    ColorScheme colorScheme,
    DateFormat timeFormatShort,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.check_mark,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Timer Complete!',
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All ${_c.allAlarmTimes.length} alarms have been triggered',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              ),
              child: Text(
                'Time Range: ${DateFormat('h:mm a').format(_c.allAlarmTimes.first)} - ${DateFormat('h:mm a').format(_c.allAlarmTimes.last)}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 260,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _c.reset();
                },
                icon: const Icon(CupertinoIcons.restart, size: 18),
                label: const Text('Restart Timer'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Timers',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
