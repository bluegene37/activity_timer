import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/interval_timer.dart';
import '../models/settings.dart';
import '../theme/for_ui.dart';
import 'package:audioplayers/audioplayers.dart';

class IntervalTimerScreen extends StatefulWidget {
  final IntervalTimer timer;

  const IntervalTimerScreen({
    super.key,
    required this.timer,
  });

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
    _audioPlayer.setSource(AssetSource('sounds/${widget.timer.alarmSound.fileName}'));
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }
  
  void _initializeTimer() {
    _currentTime = DateTime.now();
    _allAlarmTimes = widget.timer.getAllAlarmTimes();
    
    // Find the next alarm time
    if (_currentTime.isBefore(widget.timer.startTime)) {
      // If current time is before start time, first alarm is at start time
      _nextAlarmTime = widget.timer.startTime;
      _currentAlarmIndex = 0;
    } else if (_currentTime.isAfter(widget.timer.endTime)) {
      // If current time is after end time, timer is completed
      _nextAlarmTime = widget.timer.endTime;
      _currentAlarmIndex = _allAlarmTimes.length - 1;
      _isCompleted = true;
    } else {
      // Find the next alarm time
      _nextAlarmTime = widget.timer.getNextAlarmTime(_currentTime);
      _currentAlarmIndex = _allAlarmTimes.indexWhere(
        (time) => time.isAtSameMomentAs(_nextAlarmTime)
      );
      
      if (_currentAlarmIndex == -1) {
        // If no exact match, find the closest future alarm
        _currentAlarmIndex = _allAlarmTimes.indexWhere(
          (time) => time.isAfter(_currentTime)
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
      _audioPlayer.resume();
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
    if (_currentAlarmIndex < _allAlarmTimes.length - 1) {
      _currentAlarmIndex++;
      _nextAlarmTime = _allAlarmTimes[_currentAlarmIndex];
    } else {
      // All alarms completed
      _isCompleted = true;
      _timer.cancel();
    }
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
    _timer.cancel();
    setState(() {
      _isCompleted = false;
      _isRunning = true;
    });
    _initializeTimer();
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
    final timeFormat = DateFormat('h:mm:ss a');
    final timeFormatShort = DateFormat('h:mm a');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.timer.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Timer?'),
                content: const Text('Are you sure you want to exit this timer?'),
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
              color: _settings.soundEnabled ? theme.colorScheme.primary : null,
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
          ? _buildCompletedView(theme, timeFormatShort)
          : _buildRunningView(theme, timeFormat, timeFormatShort),
    );
  }
  
  Widget _buildRunningView(ThemeData theme, DateFormat timeFormat, DateFormat timeFormatShort) {
    final timeDifference = _nextAlarmTime.difference(_currentTime);
    final hours = timeDifference.inHours;
    final minutes = (timeDifference.inMinutes % 60);
    final seconds = (timeDifference.inSeconds % 60);
    
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: _currentAlarmIndex / (_allAlarmTimes.length - 1),
          minHeight: 8,
        ),
        
        // Timer info
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Current Time',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                timeFormat.format(_currentTime),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Alarm ${_currentAlarmIndex + 1} of ${_allAlarmTimes.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.notifications_active,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.timer.alarmSound.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Next alarm countdown
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next Alarm In',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeUnit(theme, hours.toString().padLeft(2, '0'), 'HR'),
                    const SizedBox(width: 8),
                    Text(':', style: theme.textTheme.displayMedium),
                    const SizedBox(width: 8),
                    _buildTimeUnit(theme, minutes.toString().padLeft(2, '0'), 'MIN'),
                    const SizedBox(width: 8),
                    Text(':', style: theme.textTheme.displayMedium),
                    const SizedBox(width: 8),
                    _buildTimeUnit(theme, seconds.toString().padLeft(2, '0'), 'SEC'),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Next Alarm: ${timeFormatShort.format(_nextAlarmTime)}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        
        // Alarm list
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Alarm Schedule',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allAlarmTimes.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final alarmTime = _allAlarmTimes[index];
                    final isCurrentAlarm = index == _currentAlarmIndex;
                    final isPastAlarm = index < _currentAlarmIndex;
                    
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isCurrentAlarm 
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : isPastAlarm
                                ? theme.colorScheme.surface
                                : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrentAlarm 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.3),
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
                                  ? theme.colorScheme.primary
                                  : isPastAlarm
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeFormatShort.format(alarmTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurrentAlarm 
                                  ? theme.colorScheme.primary
                                  : isPastAlarm
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isPastAlarm ? Icons.check_circle : Icons.circle_outlined,
                            size: 16,
                            color: isPastAlarm 
                                ? Colors.green
                                : isCurrentAlarm
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withOpacity(0.5),
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
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'reset',
                onPressed: _resetTimer,
                mini: true,
                child: const Icon(Icons.refresh),
              ),
              FloatingActionButton(
                heroTag: 'play_pause',
                onPressed: _toggleTimer,
                child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
              ),
              FloatingActionButton(
                heroTag: 'skip',
                onPressed: _moveToNextAlarm,
                mini: true,
                child: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeUnit(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
  
  Widget _buildCompletedView(ThemeData theme, DateFormat timeFormatShort) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 100,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Timer Complete!',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'All ${_allAlarmTimes.length} alarms have been triggered',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Time Range: ${timeFormatShort.format(widget.timer.startTime)} - ${timeFormatShort.format(widget.timer.endTime)}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _resetTimer,
            icon: const Icon(Icons.replay),
            label: const Text('Restart Timer'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Timers'),
          ),
        ],
      ),
    );
  }
}
