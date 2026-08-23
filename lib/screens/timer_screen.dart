import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/activity_timer.dart';
import '../models/interval_phase.dart';
import '../models/settings.dart';
import '../models/session_history.dart';
import '../services/database_service.dart';
import '../components/glowing_timer_ring.dart';
import '../utils/time_format.dart';

class TimerScreen extends StatefulWidget {
  final TimerSequence sequence;

  const TimerScreen({super.key, required this.sequence});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  late List<ActivityTimer> _timers;
  int _currentTimerIndex = 0;

  // Preparation Countdown State
  bool _isPreparing = false;
  int _prepDurationMs = 0;

  // Wall-clock based countdown
  DateTime? _deadline;
  int _remainingMs = 0;

  bool _isRunning = false;
  bool _isCompleted = false;
  bool _loopEnabled = false;
  int _loopCount = 0;
  int _lastHapticSecond = -1;
  Timer? _ticker;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _settings = AppSettings();

  int get _currentDurationMs {
    if (_timers.isEmpty) return 0;
    if (_isPreparing) return _prepDurationMs;
    return _timers[_currentTimerIndex].durationInSeconds * 1000;
  }

  int get _remainingMsNow {
    if (_isRunning && _deadline != null) {
      return _deadline!.difference(DateTime.now()).inMilliseconds;
    }
    return _remainingMs;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timers = List.from(widget.sequence.timers);
    if (_timers.isEmpty) {
      _timers = [ActivityTimer(name: 'Timer', durationInSeconds: 30, phase: IntervalPhase.work)];
    }

    _loopEnabled = widget.sequence.defaultLoopEnabled;

    if (widget.sequence.preparationSeconds > 0) {
      _isPreparing = true;
      _prepDurationMs = widget.sequence.preparationSeconds * 1000;
      _remainingMs = _prepDurationMs;
    } else {
      _isPreparing = false;
      _remainingMs = _currentDurationMs;
    }

    _updateAudioSource();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRunning) {
      _tick();
    }
  }

  void _updateAudioSource() {
    if (_timers.isEmpty) return;
    final sound = _isPreparing
        ? _settings.defaultAlarmSound
        : (_timers[_currentTimerIndex].alarmSound ?? _settings.defaultAlarmSound);
    try {
      _audioPlayer.setSource(AssetSource('sounds/${sound.fileName}'));
    } catch (_) {}
  }

  void _start() {
    _deadline = DateTime.now().add(Duration(milliseconds: _remainingMs));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    WakelockPlus.enable();
    setState(() {
      _isRunning = true;
    });
  }

  void _pause() {
    _remainingMs = math.max(0, _remainingMsNow);
    _ticker?.cancel();
    WakelockPlus.disable();
    setState(() {
      _isRunning = false;
    });
  }

  void _addSeconds(int deltaSeconds) {
    final deltaMs = deltaSeconds * 1000;
    if (_isRunning && _deadline != null) {
      final newDeadline = _deadline!.add(Duration(milliseconds: deltaMs));
      // Ensure at least 1 second remaining
      if (newDeadline.isAfter(DateTime.now().add(const Duration(seconds: 1)))) {
        _deadline = newDeadline;
      }
    } else {
      _remainingMs = math.max(1000, _remainingMs + deltaMs);
    }

    if (_settings.vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _tick() {
    if (!mounted || !_isRunning) return;

    final remaining = _deadline!.difference(DateTime.now()).inMilliseconds;
    if (remaining <= 0) {
      if (_isPreparing) {
        _finishPreparation();
      } else {
        _playAlarm();
        _advance(overshootMs: -remaining);
      }
      return;
    }

    final secondsLeft = (remaining / 1000).ceil();
    if (secondsLeft <= 3 &&
        secondsLeft != _lastHapticSecond &&
        _settings.vibrationEnabled) {
      _lastHapticSecond = secondsLeft;
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _finishPreparation() {
    _isPreparing = false;
    _currentTimerIndex = 0;
    _remainingMs = _currentDurationMs;
    _lastHapticSecond = -1;
    _playStartTone();
    _deadline = DateTime.now().add(Duration(milliseconds: _remainingMs));
    _updateAudioSource();
    setState(() {});
  }

  void _advance({int overshootMs = 0}) {
    var index = _currentTimerIndex;
    var carry = overshootMs;
    var loops = _loopCount;

    final cycleMs = widget.sequence.totalDuration * 1000;
    while (true) {
      if (index < _timers.length - 1) {
        index++;
      } else if (_loopEnabled && cycleMs > 0) {
        index = 0;
        loops++;
        if (carry >= cycleMs) {
          loops += carry ~/ cycleMs;
          carry %= cycleMs;
        }
      } else {
        _complete();
        return;
      }

      final durationMs = _timers[index].durationInSeconds * 1000;
      if (carry < durationMs) {
        _currentTimerIndex = index;
        _loopCount = loops;
        _remainingMs = durationMs - carry;
        break;
      }
      carry -= durationMs;
    }

    _lastHapticSecond = -1;
    _deadline = DateTime.now().add(Duration(milliseconds: _remainingMs));
    _updateAudioSource();
    setState(() {});
  }

  void _complete() {
    _ticker?.cancel();
    WakelockPlus.disable();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
    });
    _logSessionCompletion();
  }

  Future<void> _playStartTone() async {
    if (_settings.soundEnabled) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
        await _audioPlayer.resume();
      } catch (_) {}
    }
    if (_settings.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _playAlarm() async {
    final currentTimer = _timers[_currentTimerIndex];
    final sound = currentTimer.alarmSound ?? _settings.defaultAlarmSound;

    if (_settings.soundEnabled) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setSource(AssetSource('sounds/${sound.fileName}'));
        await _audioPlayer.resume();
      } catch (_) {}
    }

    if (_settings.vibrationEnabled) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  void _resetTimer() {
    _ticker?.cancel();
    WakelockPlus.disable();
    setState(() {
      _isPreparing = widget.sequence.preparationSeconds > 0;
      _prepDurationMs = widget.sequence.preparationSeconds * 1000;
      _currentTimerIndex = 0;
      _remainingMs = _isPreparing ? _prepDurationMs : _currentDurationMs;
      _isRunning = false;
      _isCompleted = false;
      _loopCount = 0;
      _lastHapticSecond = -1;
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
        category: widget.sequence.category,
      ),
    );
  }

  void _skipToNextTimer() {
    if (_isPreparing) {
      _finishPreparation();
      return;
    }
    if (_currentTimerIndex < _timers.length - 1 || _loopEnabled) {
      final wasRunning = _isRunning;
      _ticker?.cancel();
      _advance();
      if (wasRunning) {
        _remainingMs = _remainingMsNow;
        _start();
      } else {
        _deadline = null;
      }
    }
  }

  void _goToPreviousTimer() {
    if (_isPreparing) return;
    if (_currentTimerIndex > 0) {
      final wasRunning = _isRunning;
      _ticker?.cancel();
      setState(() {
        _currentTimerIndex--;
        _remainingMs = _currentDurationMs;
        _lastHapticSecond = -1;
        _isRunning = false;
      });
      _updateAudioSource();
      if (wasRunning) {
        _start();
      }
    }
  }

  void _toggleLoop() {
    setState(() {
      _loopEnabled = !_loopEnabled;
    });
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Activity?'),
        content: const Text('Are you sure you want to exit this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingMs = math.max(0, _remainingMsNow);
    final remainingSeconds = (remainingMs / 1000).ceil();
    final double progress = _currentDurationMs > 0
        ? (1 - (remainingMs / _currentDurationMs)).clamp(0.0, 1.0)
        : 0.0;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: _isCompleted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.sequence.name),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            onPressed: () {
              if (_isCompleted) {
                Navigator.pop(context);
              } else {
                _confirmExit();
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _settings.soundEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
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
                color: _loopEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              onPressed: _toggleLoop,
              tooltip: _loopEnabled ? 'Disable loop' : 'Enable loop',
            ),
          ],
        ),
        body: _isCompleted
            ? _buildCompletedView(textTheme, colorScheme)
            : isLandscape
                ? _buildLandscapeLayout(progress, remainingSeconds, textTheme, colorScheme)
                : _buildPortraitLayout(progress, remainingSeconds, textTheme, colorScheme),
      ),
    );
  }

  // PORTRAIT LAYOUT
  Widget _buildPortraitLayout(
    double progress,
    int remainingSeconds,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final currentTimer = _timers[_currentTimerIndex];
    final activePhase = _isPreparing ? IntervalPhase.prepare : currentTimer.phase;
    final phaseColor = _getPhaseColor(activePhase, progress, colorScheme);

    return SafeArea(
      child: Column(
        children: [
          // Sequence Progress Bar
          LinearProgressIndicator(
            value: _isPreparing
                ? 0.0
                : ((_currentTimerIndex + progress) / _timers.length).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
            color: phaseColor,
          ),
          const SizedBox(height: 16),

          // Phase & Step Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhasePill(activePhase, phaseColor),
                const SizedBox(width: 8),
                if (!_isPreparing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentTimerIndex + 1} of ${_timers.length}',
                      style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_loopEnabled && _loopCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Loop ${_loopCount + 1}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _isPreparing ? 'GET READY!' : currentTimer.name,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (!_isPreparing && currentTimer.description != null && currentTimer.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              currentTimer.description!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],

          // Centered Glowing Timer Ring
          Expanded(
            child: Center(
              child: GlowingTimerRing(
                progress: progress,
                color: phaseColor,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
                size: 280,
                strokeWidth: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TimeFormat.clock(remainingSeconds),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: 2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _isRunning ? (_isPreparing ? 'starting soon' : 'remaining') : 'paused',
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Live In-Session Adjustment Buttons (+/- 15s)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addSeconds(-15),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('-15s'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _addSeconds(15),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+15s'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Next Timer Preview
          _buildNextTimerPreview(colorScheme, textTheme),
          const SizedBox(height: 16),

          // Bottom Control Row
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 24, right: 24),
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
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 20),
                FloatingActionButton.large(
                  heroTag: 'timer_screen_play_pause',
                  onPressed: _isRunning ? _pause : _start,
                  backgroundColor: phaseColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 40),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _skipToNextTimer,
                  iconSize: 32,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
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

  // FULLSCREEN LANDSCAPE HUD (Split Layout for Gym Equipment & Desks)
  Widget _buildLandscapeLayout(
    double progress,
    int remainingSeconds,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final currentTimer = _timers[_currentTimerIndex];
    final activePhase = _isPreparing ? IntervalPhase.prepare : currentTimer.phase;
    final phaseColor = _getPhaseColor(activePhase, progress, colorScheme);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Row(
          children: [
            // Left Half: Massive Clock & Phase Badge (60% width)
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPhasePill(activePhase, phaseColor),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _isPreparing ? 'GET READY!' : currentTimer.name,
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TimeFormat.clock(remainingSeconds),
                    style: TextStyle(
                      fontSize: 88,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: 2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                      color: phaseColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),
            Container(width: 1, color: colorScheme.outlineVariant),
            const SizedBox(width: 24),

            // Right Half: Controls & Next Up (40% width)
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Next preview
                  _buildNextTimerPreview(colorScheme, textTheme),
                  const SizedBox(height: 16),

                  // Quick adjustments (+/- 15s)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _addSeconds(-15),
                        child: const Text('-15s'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _addSeconds(15),
                        child: const Text('+15s'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _goToPreviousTimer,
                        iconSize: 28,
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        heroTag: 'landscape_play_pause',
                        onPressed: _isRunning ? _pause : _start,
                        backgroundColor: phaseColor,
                        foregroundColor: Colors.white,
                        child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 32),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: _skipToNextTimer,
                        iconSize: 28,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhasePill(IntervalPhase phase, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(phase.icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            phase.displayName.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextTimerPreview(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isPreparing) {
      final firstTimer = _timers.isNotEmpty ? _timers[0] : null;
      if (firstTimer == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Starts with: ${firstTimer.name} (${TimeFormat.clock(firstTimer.durationInSeconds)})',
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentTimerIndex < _timers.length - 1) {
      final nextTimer = _timers[_currentTimerIndex + 1];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(nextTimer.phase.icon, size: 16, color: nextTimer.phase.defaultColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Next: ${nextTimer.name} (${TimeFormat.clock(nextTimer.durationInSeconds)})',
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_loopEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.loop, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Next Loop: ${_timers[0].name}',
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompletedView(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Activity Complete!', style: textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Great job! Completed ${_timers.length} intervals.',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (_loopCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Loops completed: $_loopCount',
                  style: textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.replay),
                label: const Text('Restart Activity'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Activities',
                style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPhaseColor(IntervalPhase phase, double progress, ColorScheme colorScheme) {
    Color baseColor;
    switch (phase) {
      case IntervalPhase.work:
        baseColor = const Color(0xFFFF6D00); // High-energy Orange/Amber
        break;
      case IntervalPhase.rest:
        baseColor = const Color(0xFF00B0FF); // Refreshing Cyan/Blue
        break;
      case IntervalPhase.prepare:
        baseColor = const Color(0xFFFFD600); // Golden Prep
        break;
      case IntervalPhase.cooldown:
        baseColor = const Color(0xFF00E676); // Mint Green
        break;
    }

    final hsl = HSLColor.fromColor(baseColor);
    final targetLightness = (hsl.lightness + 0.05 - (progress * 0.15)).clamp(0.25, 0.85);
    return hsl.withLightness(targetLightness).toColor();
  }
}
