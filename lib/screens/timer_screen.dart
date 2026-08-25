import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../components/glowing_timer_ring.dart';
import '../controllers/activity_run_controller.dart';
import '../models/activity_timer.dart';
import '../models/interval_phase.dart';
import '../models/settings.dart';
import '../services/activity_session_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.sequence, this.controller});

  final TimerSequence sequence;

  /// Test seam: production borrows the controller from
  /// [ActivitySessionService].
  final ActivityRunController? controller;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // The session service owns the production controller, so popping this
  // screen minimizes the routine instead of killing it. The engine — the
  // clock, cues, looping, alarms, history — lives in the controller.
  late final ActivityRunController _c =
      widget.controller ?? ActivitySessionService().obtain(widget.sequence);
  final _settings = AppSettings();

  @override
  void dispose() {
    if (widget.controller == null) {
      // A running routine survives the pop (the floater offers the way
      // back); a completed one has nothing to keep alive.
      ActivitySessionService().releaseIfIdle();
    }
    super.dispose();
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
                  ActivitySessionService().clear();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Every observable read must happen INSIDE the Obx builder: Obx only
    // subscribes to what its own closure touches, so reading the clock
    // above this line would leave the screen frozen.
    return Obx(() {
      final remainingMs = math.max(0, _c.remainingMs.value);
      final remainingSeconds = (remainingMs / 1000).ceil();
      final double progress =
          _c.currentDurationMs > 0
              ? (1 - (remainingMs / _c.currentDurationMs)).clamp(0.0, 1.0)
              : 0.0;

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.sequence.name),
          centerTitle: true,
          // Popping minimizes: a running routine keeps ticking in the
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
              tooltip: 'End routine',
              onPressed: () {
                if (_c.isCompleted.value) {
                  Navigator.pop(context);
                } else {
                  _confirmExit();
                }
              },
            ),
            IconButton(
              icon: Icon(
                _c.loopEnabled.value
                    ? CupertinoIcons.repeat
                    : CupertinoIcons.repeat,
                color:
                    _c.loopEnabled.value
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                _c.toggleLoop();
              },
              tooltip: _c.loopEnabled.value ? 'Disable loop' : 'Enable loop',
            ),
            const SizedBox(width: 4),
          ],
        ),
        body:
            _c.isCompleted.value
                ? _buildCompletedView(textTheme, colorScheme)
                : isLandscape
                ? _buildLandscapeLayout(
                  progress,
                  remainingSeconds,
                  textTheme,
                  colorScheme,
                )
                : _buildPortraitLayout(
                  progress,
                  remainingSeconds,
                  textTheme,
                  colorScheme,
                ),
      );
    });
  }

  // PORTRAIT LAYOUT
  Widget _buildPortraitLayout(
    double progress,
    int remainingSeconds,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final currentTimer = _c.timers[_c.currentIndex.value];
    final activePhase =
        _c.isPreparing.value ? IntervalPhase.prepare : currentTimer.phase;
    final phaseColor = _getPhaseColor(activePhase, progress);

    return SafeArea(
      child: Column(
        children: [
          // Sequence Progress Bar (iOS Thin Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:
                  _c.isPreparing.value
                      ? 0.0
                      : ((_c.currentIndex.value + progress) / _c.timers.length)
                          .clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
              color: phaseColor,
            ),
          ),
          const SizedBox(height: 16),

          // Phase & Step Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhasePill(activePhase, phaseColor),
                const SizedBox(width: 8),
                if (!_c.isPreparing.value) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                    ),
                    child: Text(
                      '${_c.currentIndex.value + 1} of ${_c.timers.length}',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_c.loopEnabled.value && _c.loopCount.value > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.pillRadius,
                        ),
                      ),
                      child: Text(
                        'Loop ${_c.loopCount.value + 1}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
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
            _c.isPreparing.value ? 'GET READY!' : currentTimer.name,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),
          if (!_c.isPreparing.value &&
              currentTimer.description != null &&
              currentTimer.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              currentTimer.description!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],

          // Centered Glowing Timer Ring (Apple Fitness Ring)
          Expanded(
            child: Center(
              child: GlowingTimerRing(
                progress: progress,
                color: phaseColor,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                size: 280,
                strokeWidth: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TimeFormat.clock(remainingSeconds),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _c.isRunning.value
                          ? (_c.isPreparing.value
                              ? 'starting soon'
                              : 'remaining')
                          : 'paused',
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

          // Live In-Session Adjustment Buttons (+/- 15s)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _c.addSeconds(-15);
                  },
                  icon: const Icon(CupertinoIcons.minus, size: 14),
                  label: const Text('-15s'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _c.addSeconds(15);
                  },
                  icon: const Icon(CupertinoIcons.plus, size: 14),
                  label: const Text('+15s'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Next Timer Preview
          _buildNextTimerPreview(colorScheme, textTheme),
          const SizedBox(height: 18),

          // Bottom Control Row
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    _c.goToPrevious();
                  },
                  iconSize: 28,
                  color: colorScheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(width: 24),
                FloatingActionButton.large(
                  heroTag: 'timer_screen_play_pause',
                  onPressed: () {
                    unawaited(HapticFeedback.mediumImpact());
                    _c.isRunning.value ? _c.pause() : _c.start();
                  },
                  backgroundColor: phaseColor,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: Icon(
                    _c.isRunning.value ? Icons.pause : Icons.play_arrow,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    _c.skipToNext();
                  },
                  iconSize: 28,
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
    final currentTimer = _c.timers[_c.currentIndex.value];
    final activePhase =
        _c.isPreparing.value ? IntervalPhase.prepare : currentTimer.phase;
    final phaseColor = _getPhaseColor(activePhase, progress);

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
                          _c.isPreparing.value
                              ? 'GET READY!'
                              : currentTimer.name,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                      letterSpacing: -2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.1,
                      ),
                      color: phaseColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),
            Container(width: 0.8, color: colorScheme.outlineVariant),
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
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          _c.addSeconds(-15);
                        },
                        child: const Text('-15s'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          _c.addSeconds(15);
                        },
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
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          _c.goToPrevious();
                        },
                        iconSize: 26,
                      ),
                      const SizedBox(width: 14),
                      FloatingActionButton(
                        heroTag: 'landscape_play_pause',
                        onPressed: () {
                          unawaited(HapticFeedback.mediumImpact());
                          _c.isRunning.value ? _c.pause() : _c.start();
                        },
                        backgroundColor: phaseColor,
                        foregroundColor: Colors.white,
                        child: Icon(
                          _c.isRunning.value ? Icons.pause : Icons.play_arrow,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          _c.skipToNext();
                        },
                        iconSize: 26,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(phase.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            phase.displayName.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextTimerPreview(ColorScheme colorScheme, TextTheme textTheme) {
    if (_c.isPreparing.value) {
      final firstTimer = _c.timers.isNotEmpty ? _c.timers[0] : null;
      if (firstTimer == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.play_circle,
              size: 15,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Starts with: ${firstTimer.name} (${TimeFormat.clock(firstTimer.durationInSeconds)})',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_c.currentIndex.value < _c.timers.length - 1) {
      final nextTimer = _c.timers[_c.currentIndex.value + 1];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              nextTimer.phase.icon,
              size: 15,
              color: nextTimer.phase.defaultColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Next: ${nextTimer.name} (${TimeFormat.clock(nextTimer.durationInSeconds)})',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_c.loopEnabled.value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.repeat, size: 15, color: colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Next Loop: ${_c.timers[0].name}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
              'Activity Complete!',
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Great job! Completed ${_c.timers.length} intervals.',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_c.loopCount.value > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                ),
                child: Text(
                  'Loops completed: $_c.loopCount.value',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _c.reset();
                },
                icon: const Icon(CupertinoIcons.restart, size: 18),
                label: const Text('Restart Activity'),
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
                'Back to Activities',
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

  /// Phase accent, brightened at the start of a step and dimmed as it runs out.
  Color _getPhaseColor(IntervalPhase phase, double progress) {
    final baseColor = switch (phase) {
      IntervalPhase.work => AppTheme.iosOrange, // High-energy Apple Orange
      IntervalPhase.rest => AppTheme.iosBlue, // Apple Blue
      IntervalPhase.prepare => AppTheme.iosYellow, // Apple Yellow Prep
      IntervalPhase.cooldown => AppTheme.iosGreen, // Apple Mint/Green
    };

    final hsl = HSLColor.fromColor(baseColor);
    final targetLightness = (hsl.lightness + 0.05 - progress * 0.15).clamp(
      0.25,
      0.85,
    );
    return hsl.withLightness(targetLightness).toColor();
  }
}
