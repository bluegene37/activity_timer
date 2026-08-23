import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../components/glowing_timer_ring.dart';
import '../models/interval_timer.dart';
import '../models/session_history.dart';
import '../models/settings.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class IntervalTimerScreen extends StatefulWidget {
  final IntervalTimer timer;

  const IntervalTimerScreen({super.key, required this.timer});

  @override
  State<IntervalTimerScreen> createState() => _IntervalTimerScreenState();
}

class _IntervalTimerScreenState extends State<IntervalTimerScreen> {
  late DateTime _currentTime;
  late DateTime _nextAlarmTime;
  late List<DateTime> _allAlarmTimes;
  late int _currentAlarmIndex;
  late Timer _timer;
  bool _isRunning = true;
  bool _isCompleted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _initializeTimer();

    // Load the alarm sound
    _audioPlayer.setSource(
      AssetSource('sounds/${widget.timer.alarmSound.fileName}'),
    );
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _initializeTimer() {
    final now = DateTime.now();
    _currentTime = now;

    // Normalize start and end times to the current day
    DateTime normalizedStart = DateTime(
      now.year,
      now.month,
      now.day,
      widget.timer.startTime.hour,
      widget.timer.startTime.minute,
      widget.timer.startTime.second,
    );

    DateTime normalizedEnd = DateTime(
      now.year,
      now.month,
      now.day,
      widget.timer.endTime.hour,
      widget.timer.endTime.minute,
      widget.timer.endTime.second,
    );

    // If normalized end time is before normalized start time,
    // it means the range crosses midnight. Adjust the end time
    // to the next day.
    if (normalizedEnd.isBefore(normalizedStart)) {
      normalizedEnd = normalizedEnd.add(const Duration(days: 1));
    }

    // If the entire window is in the past, shift it to the next day
    if (now.isAfter(normalizedEnd)) {
      normalizedStart = normalizedStart.add(const Duration(days: 1));
      normalizedEnd = normalizedEnd.add(const Duration(days: 1));
    }

    // Create a temporary timer model with normalized dates to calculate alarms
    final tempTimer = IntervalTimer(
      id: widget.timer.id,
      name: widget.timer.name,
      startTime: normalizedStart,
      endTime: normalizedEnd,
      intervalValue: widget.timer.intervalValue,
      intervalType: widget.timer.intervalType,
    );

    _allAlarmTimes = tempTimer.getAllAlarmTimes();

    // Find the next alarm time
    if (_currentTime.isBefore(normalizedStart)) {
      // If current time is before start time, first alarm is at start time
      _nextAlarmTime = normalizedStart;
      _currentAlarmIndex = 0;
    } else if (_currentTime.isAfter(normalizedEnd)) {
      // Should not happen with the normalization logic above, but for safety:
      _nextAlarmTime = normalizedEnd;
      _currentAlarmIndex = _allAlarmTimes.length - 1;
      _isCompleted = true;
    } else {
      // Find the next alarm time using the normalized timer
      _nextAlarmTime = tempTimer.getNextAlarmTime(_currentTime);
      _currentAlarmIndex = _allAlarmTimes.indexWhere(
        (time) =>
            time.year == _nextAlarmTime.year &&
            time.month == _nextAlarmTime.month &&
            time.day == _nextAlarmTime.day &&
            time.hour == _nextAlarmTime.hour &&
            time.minute == _nextAlarmTime.minute &&
            time.second == _nextAlarmTime.second,
      );

      if (_currentAlarmIndex == -1) {
        // If no exact match, find the closest future alarm
        _currentAlarmIndex = _allAlarmTimes.indexWhere(
          (time) => time.isAfter(_currentTime),
        );

        if (_currentAlarmIndex == -1) {
          // If all alarms are in the past, timer is completed
          _currentAlarmIndex = _allAlarmTimes.length - 1;
          _isCompleted = true;
        } else {
          _nextAlarmTime = _allAlarmTimes[_currentAlarmIndex];
        }
      }
    }

    // Start the timer
    _startTimer();
  }

  void _startTimer() {
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();

        // Check if it's time for the alarm
        if (!_currentTime.isBefore(_nextAlarmTime)) {
          _triggerAlarm();
          // Advance past every alarm that already elapsed (several may have
          // passed at once if the app was backgrounded), sounding only once.
          while (!_isCompleted && !_currentTime.isBefore(_nextAlarmTime)) {
            _moveToNextAlarm();
          }
        }
      });
    });
  }

  void _triggerAlarm() {
    // Play sound if enabled
    if (_settings.soundEnabled) {
      try {
        _audioPlayer.stop().then((_) {
          _audioPlayer
              .setSource(
                AssetSource('sounds/${widget.timer.alarmSound.fileName}'),
              )
              .then((_) => _audioPlayer.resume());
        });
      } catch (_) {}
    }

    // Vibrate if enabled
    if (_settings.vibrationEnabled) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  void _moveToNextAlarm() {
    setState(() {
      if (_currentAlarmIndex < _allAlarmTimes.length - 1) {
        _currentAlarmIndex++;
        _nextAlarmTime = _allAlarmTimes[_currentAlarmIndex];
      } else {
        // All alarms completed
        _isCompleted = true;
        _timer.cancel();
        WakelockPlus.disable();
        _logSessionCompletion();
      }
    });
  }

  void _logSessionCompletion() {
    final durationInSeconds = _allAlarmTimes.last.difference(_allAlarmTimes.first).inSeconds;
    DatabaseService().logSessionHistory(
      SessionHistory(
        title: widget.timer.name,
        totalDurationInSeconds: durationInSeconds > 0 ? durationInSeconds : 60,
        itemCount: _allAlarmTimes.length,
        loopCount: 0,
        sessionType: 'interval',
      ),
    );
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer.cancel();
      WakelockPlus.disable();
    } else {
      _startTimer();
    }

    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      _isCompleted = false;
      _isRunning = true;
    });
    _initializeTimer();
  }

  int _getTotalIntervalSeconds() {
    switch (widget.timer.intervalType) {
      case IntervalType.hour:
        return widget.timer.intervalValue * 3600;
      case IntervalType.minute:
        return widget.timer.intervalValue * 60;
      case IntervalType.second:
        return widget.timer.intervalValue;
    }
  }

  Color _getTimerColor(double progress, ColorScheme colorScheme) {
    final HSLColor baseColor = HSLColor.fromColor(colorScheme.primary);
    double targetLightness = (baseColor.lightness + 0.15) - (progress * 0.3);
    targetLightness = targetLightness.clamp(0.2, 0.8);
    return baseColor.withLightness(targetLightness).toColor();
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

    return PopScope(
      canPop: _isCompleted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.timer.name),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(CupertinoIcons.xmark, color: colorScheme.onSurface, size: 22),
            onPressed: () {
              if (_isCompleted) {
                Navigator.pop(context);
              } else {
                _confirmExit();
              }
            },
          ),
          actions: [
            // Sound toggle button
            IconButton(
              icon: Icon(
                _settings.soundEnabled ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_slash_fill,
                color: _settings.soundEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
            const SizedBox(width: 4),
          ],
        ),
        body: _isCompleted
            ? _buildCompletedView(textTheme, colorScheme, timeFormatShort)
            : _buildRunningView(textTheme, colorScheme, timeFormat, timeFormatShort),
      ),
    );
  }

  Widget _buildRunningView(
    TextTheme textTheme,
    ColorScheme colorScheme,
    DateFormat timeFormat,
    DateFormat timeFormatShort,
  ) {
    final timeDifference = _nextAlarmTime.difference(_currentTime);
    final hours = timeDifference.inHours;
    final minutes = timeDifference.inMinutes % 60;
    final seconds = timeDifference.inSeconds % 60;

    // Calculate progress for the current interval
    final totalSeconds = _getTotalIntervalSeconds();
    final remainingSeconds = timeDifference.inSeconds;
    
    double progress = totalSeconds > 0 ? 1.0 - (remainingSeconds / totalSeconds) : 0.0;
    progress = progress.clamp(0.0, 1.0);

    return SafeArea(
      child: Column(
        children: [
          // Progress indicator (iOS Thin Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _allAlarmTimes.length > 1
                  ? (_currentAlarmIndex / (_allAlarmTimes.length - 1)).clamp(0.0, 1.0)
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
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  timeFormat.format(_currentTime),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Alarm ${_currentAlarmIndex + 1} of ${_allAlarmTimes.length}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Alarm Schedule',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Next: ${timeFormatShort.format(_nextAlarmTime)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _allAlarmTimes.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final alarmTime = _allAlarmTimes[index];
                      final isCurrentAlarm = index == _currentAlarmIndex;
                      final isPastAlarm = index < _currentAlarmIndex;

                      return Container(
                        width: 78,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: isCurrentAlarm
                              ? colorScheme.primary.withValues(alpha: 0.12)
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentAlarm
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
                                color: isCurrentAlarm
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
                                fontWeight: isCurrentAlarm ? FontWeight.w700 : FontWeight.normal,
                                color: isCurrentAlarm
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
                              color: isPastAlarm
                                  ? AppTheme.iosGreen
                                  : isCurrentAlarm
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.restart),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _resetTimer();
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
                    _toggleTimer();
                  },
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: Icon(_isRunning ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 36),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(CupertinoIcons.forward_fill),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _moveToNextAlarm();
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

  Widget _buildCompletedView(TextTheme textTheme, ColorScheme colorScheme, DateFormat timeFormatShort) {
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
              'All ${_allAlarmTimes.length} alarms have been triggered',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              ),
              child: Text(
                'Time Range: ${DateFormat('h:mm a').format(_allAlarmTimes.first)} - ${DateFormat('h:mm a').format(_allAlarmTimes.last)}',
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 260,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _resetTimer();
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
              child: Text('Back to Timers', style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
