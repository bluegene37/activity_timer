import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/interval_timer.dart';
import '../models/settings.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../components/glowing_timer_ring.dart';

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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();

        // Check if it's time for the alarm
        if (_currentTime.isAfter(_nextAlarmTime) ||
            _currentTime.isAtSameMomentAs(_nextAlarmTime)) {
          _triggerAlarm();
          _moveToNextAlarm();
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
      // For longer vibration on supported devices
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
      }
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer.cancel();
    } else {
      _startTimer();
    }

    setState(() {
      _isRunning = !_isRunning;
    });
  }

  void _resetTimer() {
    _timer.cancel(); // Fix: Cancel before starting over
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
    
    // Map progress from 0.0 to 1.0 to a lightness range: lighter to darker
    // Example: Start at lightness + 0.15, end at lightness - 0.15
    double targetLightness = (baseColor.lightness + 0.15) - (progress * 0.3);
    
    // Clamp to ensure it doesn't become too white or completely black
    targetLightness = targetLightness.clamp(0.2, 0.8);
    
    return baseColor.withLightness(targetLightness).toColor();
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final timeFormat = DateFormat('h:mm:ss a');
    final timeFormatShort = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.timer.name),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Exit Timer?'),
                    content: const Text(
                      'Are you sure you want to exit this timer?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Close timer screen
                        },
                        child: const Text('Exit'),
                      ),
                    ],
                  ),
            );
          },
        ),
        actions: [
          // Sound toggle button
          IconButton(
            icon: Icon(
              _settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: _settings.soundEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: () async {
              bool newValue = !_settings.soundEnabled;
              await _settings.setSoundEnabled(newValue);
              setState(() {});
            },
            tooltip: _settings.soundEnabled ? 'Mute sound' : 'Enable sound',
          ),
        ],
      ),
      body: _isCompleted
              ? _buildCompletedView(textTheme, colorScheme, timeFormatShort)
              : _buildRunningView(textTheme, colorScheme, timeFormat, timeFormatShort),
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
    final minutes = (timeDifference.inMinutes % 60);
    final seconds = (timeDifference.inSeconds % 60);

    // Calculate progress for the current interval
    final totalSeconds = _getTotalIntervalSeconds();
    final remainingSeconds = timeDifference.inSeconds;
    
    // Progress goes from 0 (just started interval) to 1.0 (about to trigger alarm)
    double progress = totalSeconds > 0 ? 1.0 - (remainingSeconds / totalSeconds) : 0.0;
    progress = progress.clamp(0.0, 1.0);

    return SafeArea(
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: _currentAlarmIndex / (_allAlarmTimes.length - 1),
            minHeight: 6,
            backgroundColor: colorScheme.onSurface.withOpacity(0.08),
            color: colorScheme.primary,
          ),

          // Timer info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                Text('Current Time', style: textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(_currentTime),
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Alarm ${_currentAlarmIndex + 1} of ${_allAlarmTimes.length}',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.notifications_active,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.timer.alarmSound.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
                backgroundColor: colorScheme.onSurface.withOpacity(0.05),
                size: 300,
                strokeWidth: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${hours > 0 ? '${hours.toString()}:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: hours > 0 ? 48 : 64,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'till next alarm',
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alarm list
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Alarm Schedule',
                        style: textTheme.titleSmall,
                      ),
                      Text(
                        'Next: ${timeFormatShort.format(_nextAlarmTime)}',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
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
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentAlarm
                                  ? colorScheme.primary.withOpacity(0.1)
                                  : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentAlarm
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                            width: isCurrentAlarm ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCurrentAlarm
                                        ? colorScheme.primary
                                        : isPastAlarm
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeFormatShort.format(alarmTime),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrentAlarm ? FontWeight.bold : FontWeight.normal,
                                color: isCurrentAlarm
                                        ? colorScheme.primary
                                        : isPastAlarm
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              isPastAlarm
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isPastAlarm
                                      ? Colors.green
                                      : isCurrentAlarm
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetTimer,
                  iconSize: 28,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 24),
                FloatingActionButton.large(
                  heroTag: 'play_pause',
                  onPressed: _toggleTimer,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 40),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _moveToNextAlarm,
                  iconSize: 28,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.task_alt, size: 100, color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text('Timer Complete!', style: textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text(
            'All ${_allAlarmTimes.length} alarms have been triggered',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Time Range: ${DateFormat('h:mm a').format(_allAlarmTimes.first)} - ${DateFormat('h:mm a').format(_allAlarmTimes.last)}',
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton.icon(
              onPressed: _resetTimer,
              icon: const Icon(Icons.replay),
              label: const Text('Restart Timer'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Back to Timers', style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
