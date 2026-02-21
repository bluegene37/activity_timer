import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/activity_timer.dart';
import '../models/settings.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/glowing_timer_ring.dart';

class TimerScreen extends StatefulWidget {
  final TimerSequence sequence;

  const TimerScreen({super.key, required this.sequence});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  late List<ActivityTimer> _timers;
  int _currentTimerIndex = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _loopEnabled = false;
  int _loopCount = 0;
  Timer? _timer;
  late AnimationController _animationController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _timers = List.from(widget.sequence.timers);
    _remainingSeconds = _timers.first.durationInSeconds;
    _loopEnabled = widget.sequence.defaultLoopEnabled;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _remainingSeconds),
    );
    _startTimer();

    // Load the alarm sound — use the user's selected default alarm sound
    _audioPlayer.setSource(
      AssetSource('sounds/${_settings.defaultAlarmSound.fileName}'),
    );
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _animationController.duration = Duration(seconds: _remainingSeconds);
      _animationController.forward(from: 0);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _playAlarm();
          _moveToNextTimer();
        }
      });
    });
  }

  Future<void> _playAlarm() async {
    // Play sound if enabled
    if (_settings.soundEnabled) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setSource(
          AssetSource('sounds/${_settings.defaultAlarmSound.fileName}'),
        );
        await _audioPlayer.resume();
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

  void _pauseTimer() {
    _timer?.cancel();
    _animationController.stop();
    setState(() {
      _isRunning = false;
    });
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _animationController.reset();
    setState(() {
      _currentTimerIndex = 0;
      _remainingSeconds = _timers.first.durationInSeconds;
      _isRunning = false;
      _isCompleted = false;
      _loopCount = 0;
      // Keep loop setting as is
    });
  }

  void _moveToNextTimer() {
    _timer?.cancel();
    _animationController.reset();

    if (_currentTimerIndex < _timers.length - 1) {
      setState(() {
        _currentTimerIndex++;
        _remainingSeconds = _timers[_currentTimerIndex].durationInSeconds;
        _animationController.duration = Duration(seconds: _remainingSeconds);
        _animationController.forward(from: 0);
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _playAlarm();
            _moveToNextTimer();
          }
        });
      });
    } else {
      // End of sequence reached
      if (_loopEnabled) {
        // If loop is enabled, restart the sequence
        setState(() {
          _loopCount++;
          _currentTimerIndex = 0;
          _remainingSeconds = _timers.first.durationInSeconds;
          _animationController.duration = Duration(seconds: _remainingSeconds);
          _animationController.forward(from: 0);
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            } else {
              _playAlarm();
              _moveToNextTimer();
            }
          });
        });
      } else {
        // If loop is not enabled, complete the activity
        setState(() {
          _isRunning = false;
          _isCompleted = true;
        });
      }
    }
  }

  void _skipToNextTimer() {
    if (_currentTimerIndex < _timers.length - 1) {
      _moveToNextTimer();
    } else if (_loopEnabled) {
      // On last timer with loop — wrap around
      _moveToNextTimer();
    }
  }

  void _goToPreviousTimer() {
    if (_currentTimerIndex > 0) {
      final wasRunning = _isRunning;
      _timer?.cancel();
      _animationController.reset();
      setState(() {
        _currentTimerIndex--;
        _remainingSeconds = _timers[_currentTimerIndex].durationInSeconds;
        _isRunning = false;
      });
      if (wasRunning) {
        _startTimer();
      }
    }
  }

  void _toggleLoop() {
    setState(() {
      _loopEnabled = !_loopEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTimer = _timers[_currentTimerIndex];
    // Always show the real elapsed progress, even when paused
    final double progress =
        currentTimer.durationInSeconds > 0
            ? 1 - (_remainingSeconds / currentTimer.durationInSeconds)
            : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sequence.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Exit Activity?'),
                    content: const Text(
                      'Are you sure you want to exit this activity?',
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
              color:
                  _settings.soundEnabled
                      ? Theme.of(context).colorScheme.primary
                      : null,
            ),
            onPressed: () async {
              bool newValue = !_settings.soundEnabled;
              await _settings.setSoundEnabled(newValue);
              setState(() {});
            },
            tooltip: _settings.soundEnabled ? 'Mute sound' : 'Enable sound',
          ),
          // Loop toggle button
          IconButton(
            icon: Icon(
              _loopEnabled ? Icons.repeat_on : Icons.repeat,
              color:
                  _loopEnabled ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: _toggleLoop,
            tooltip: _loopEnabled ? 'Disable loop' : 'Enable loop',
          ),
        ],
      ),
      body:
          _isCompleted
              ? _buildCompletedView()
              : _buildTimerView(currentTimer, progress),
    );
  }

  Widget _buildTimerView(ActivityTimer currentTimer, double progress) {
    return Column(
      children: [
        // Progress indicator for the entire sequence
        LinearProgressIndicator(
          value: (_currentTimerIndex + progress) / _timers.length,
          minHeight: 8,
        ),

        // Timer info
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Timer ${_currentTimerIndex + 1} of ${_timers.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_loopEnabled && _loopCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Loop ${_loopCount + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                currentTimer.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (currentTimer.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  currentTimer.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        // Timer circle
        Expanded(
          child: Center(
            child: Center(
              child: GlowingTimerRing(
                progress: progress,
                color: _getTimerColor(progress),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                size: 280, // Slightly larger for premium feel
                strokeWidth: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'remaining',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Notification indicators
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_settings.soundEnabled) ...[
                Icon(
                  Icons.volume_up,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sound',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_settings.vibrationEnabled) ...[
                Icon(
                  Icons.vibration,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Vibration',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_loopEnabled) ...[
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Loop',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (_loopCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($_loopCount)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Next timer preview
        if (_currentTimerIndex < _timers.length - 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next: ${_timers[_currentTimerIndex + 1].name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _formatTime(
                              _timers[_currentTimerIndex + 1].durationInSeconds,
                            ),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (_loopEnabled) ...[
          // Show first timer as next if we're on the last timer and looping
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.loop),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Loop: ${_timers[0].name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _formatTime(_timers[0].durationInSeconds),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Control buttons
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: _goToPreviousTimer,
                iconSize: 36,
              ),
              FloatingActionButton(
                onPressed: _isRunning ? _pauseTimer : _resumeTimer,
                child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: _skipToNextTimer,
                iconSize: 36,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center, // Change to fitness icon
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Activity Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'You completed ${_timers.length} timers',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_loopCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Loops completed: $_loopCount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _resetTimer,
            icon: const Icon(Icons.replay),
            label: const Text('Restart Activity'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Activities'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Color _getTimerColor(double progress) {
    if (progress < 0.5) {
      return Theme.of(
        context,
      ).colorScheme.primary; // Primary color for first half
    } else if (progress < 0.75) {
      return Colors.orange; // Orange for next quarter
    } else {
      return Colors.red; // Red for last quarter
    }
  }
}
