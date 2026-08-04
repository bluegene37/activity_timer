import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/activity_timer.dart';
import '../models/settings.dart';
import '../models/session_history.dart';
import '../services/database_service.dart';
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

    // Load initial alarm sound
    _updateAudioSource();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _updateAudioSource() {
    final sound = _timers[_currentTimerIndex].alarmSound ?? _settings.defaultAlarmSound;
    _audioPlayer.setSource(AssetSource('sounds/${sound.fileName}'));
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
          if (_remainingSeconds <= 3 && _remainingSeconds > 0 && _settings.vibrationEnabled) {
            HapticFeedback.selectionClick();
          }
        } else {
          _playAlarm();
          _moveToNextTimer();
        }
      });
    });
  }

  Future<void> _playAlarm() async {
    final currentTimer = _timers[_currentTimerIndex];
    final sound = currentTimer.alarmSound ?? _settings.defaultAlarmSound;

    // Play sound if enabled
    if (_settings.soundEnabled) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setSource(
          AssetSource('sounds/${sound.fileName}'),
        );
        await _audioPlayer.resume();
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
    });
    _updateAudioSource();
  }

  void _logSessionCompletion() {
    DatabaseService().logSessionHistory(
      SessionHistory(
        title: widget.sequence.name,
        totalDurationInSeconds: widget.sequence.totalDuration * (_loopCount + 1),
        itemCount: _timers.length,
        loopCount: _loopCount,
        sessionType: 'activity',
      ),
    );
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
      _updateAudioSource();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            if (_remainingSeconds <= 3 && _remainingSeconds > 0 && _settings.vibrationEnabled) {
              HapticFeedback.selectionClick();
            }
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
        _updateAudioSource();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
              if (_remainingSeconds <= 3 && _remainingSeconds > 0 && _settings.vibrationEnabled) {
                HapticFeedback.selectionClick();
              }
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
        _logSessionCompletion();
      }
    }
  }

  void _skipToNextTimer() {
    if (_currentTimerIndex < _timers.length - 1) {
      _moveToNextTimer();
    } else if (_loopEnabled) {
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
      _updateAudioSource();
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.sequence.name),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
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
          IconButton(
            icon: Icon(
              _loopEnabled ? Icons.repeat_on : Icons.repeat,
              color: _loopEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: _toggleLoop,
            tooltip: _loopEnabled ? 'Disable loop' : 'Enable loop',
          ),
        ],
      ),
      body: _isCompleted
              ? _buildCompletedView(textTheme, colorScheme)
              : _buildTimerView(currentTimer, progress, textTheme, colorScheme),
    );
  }

  Widget _buildTimerView(ActivityTimer currentTimer, double progress, TextTheme textTheme, ColorScheme colorScheme) {
    final timerSound = currentTimer.alarmSound ?? _settings.defaultAlarmSound;

    return SafeArea(
      child: Column(
        children: [
          // Progress indicator for the entire sequence
          LinearProgressIndicator(
            value: (_currentTimerIndex + progress) / _timers.length,
            minHeight: 6,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),

          // Timer info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Timer ${_currentTimerIndex + 1} of ${_timers.length}',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, size: 12, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            timerSound.displayName,
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (_loopEnabled && _loopCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Loop ${_loopCount + 1}',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currentTimer.name,
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                if (currentTimer.description != null && currentTimer.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    currentTimer.description!,
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Timer circle
          Expanded(
            child: Center(
              child: GlowingTimerRing(
                progress: progress,
                color: _getTimerColor(progress, colorScheme),
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                size: 300,
                strokeWidth: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'remaining',
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next timer preview
          if (_currentTimerIndex < _timers.length - 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_forward, color: colorScheme.onSurfaceVariant, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next: ${_timers[_currentTimerIndex + 1].name}', style: textTheme.titleSmall),
                          Text(
                            _formatTime(_timers[_currentTimerIndex + 1].durationInSeconds),
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_loopEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.loop, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next Loop: ${_timers[0].name}', style: textTheme.titleSmall),
                          Text(
                            _formatTime(_timers[0].durationInSeconds),
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),

          // Control buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _goToPreviousTimer,
                  iconSize: 32,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 24),
                FloatingActionButton.large(
                  onPressed: _isRunning ? _pauseTimer : _resumeTimer,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 40),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _skipToNextTimer,
                  iconSize: 32,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
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

  Widget _buildCompletedView(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              size: 100,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Activity Complete!',
            style: textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Great job! You completed ${_timers.length} timers.',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (_loopCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Loops completed: $_loopCount',
                style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ElevatedButton.icon(
              onPressed: _resetTimer,
              icon: const Icon(Icons.replay),
              label: const Text('Restart Activity'),
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
            child: Text('Back to Activities', style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
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

  Color _getTimerColor(double progress, ColorScheme colorScheme) {
    final HSLColor baseColor = HSLColor.fromColor(colorScheme.primary);
    
    // Calculate lightness transitioning from lighter to darker.
    double targetLightness = (baseColor.lightness + 0.15) - (progress * 0.30);
    targetLightness = targetLightness.clamp(0.2, 0.85);
    
    return baseColor.withLightness(targetLightness).toColor();
  }
}
