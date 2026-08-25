import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/activity_timer.dart';
import '../models/alarm_sound.dart';
import '../models/interval_phase.dart';
import '../models/session_history.dart';
import '../models/settings.dart';
import '../services/alarm_scheduler.dart';
import '../services/cue_player.dart';
import '../services/database_service.dart';

/// Runs an activity routine on the clock, decoupled from any screen.
///
/// This is the engine that used to live inside `TimerScreen`: the
/// preparation countdown, the wall-clock deadline per step, looping, cues,
/// background alarms, and session history. Owning it here (via
/// `ActivitySessionService`) lets the screen be popped — minimized — without
/// stopping the routine, and lets the whole thing be tested with a fake
/// clock instead of a widget tree.
class ActivityRunController extends GetxController {
  ActivityRunController({
    required this.sequence,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
    Future<void> Function(SessionHistory)? historyLogger,
    Future<void> Function(TimerSequence)? sequenceSaver,
    this.tickInterval = const Duration(milliseconds: 100),
  }) : _cuePlayer = cuePlayer ?? AudioCuePlayer(),
       _scheduler = scheduler ?? LocalNotificationAlarmScheduler(),
       _now = clock ?? DateTime.now,
       _logHistory =
           historyLogger ??
           ((history) => DatabaseService().logSessionHistory(history)),
       _saveSequence =
           sequenceSaver ??
           ((seq) => DatabaseService().updateActivitySequence(seq));

  final TimerSequence sequence;
  final Duration tickInterval;

  final CuePlayer _cuePlayer;
  final AlarmScheduler _scheduler;
  final DateTime Function() _now;
  final Future<void> Function(SessionHistory) _logHistory;
  final Future<void> Function(TimerSequence) _saveSequence;

  /// The steps being run. A routine saved with no steps still has to run
  /// something, so it falls back to a single 30-second work step.
  late final List<ActivityTimer> timers =
      sequence.timers.isEmpty
          ? [
            ActivityTimer(
              name: 'Timer',
              durationInSeconds: 30,
              phase: IntervalPhase.work,
            ),
          ]
          : List<ActivityTimer>.from(sequence.timers);

  final RxInt currentIndex = 0.obs;
  final RxBool isPreparing = false.obs;
  final RxBool isRunning = false.obs;
  final RxBool isCompleted = false.obs;
  final RxBool loopEnabled = false.obs;
  final RxInt loopCount = 0.obs;

  /// Milliseconds left in the current step. Driven by the ticker so the
  /// screen can observe it without rebuilding on anything else.
  final RxInt remainingMs = 0.obs;

  Timer? _ticker;
  DateTime? _deadline;
  int _prepDurationMs = 0;
  int _lastHapticSecond = -1;

  ActivityTimer get currentTimer => timers[currentIndex.value];

  int get currentDurationMs =>
      isPreparing.value
          ? _prepDurationMs
          : timers[currentIndex.value].durationInSeconds * 1000;

  /// The live remaining time: derived from the deadline while running, and
  /// from the stored value while paused.
  int get remainingMsNow {
    final deadline = _deadline;
    if (isRunning.value && deadline != null) {
      return deadline.difference(_now()).inMilliseconds;
    }
    return remainingMs.value;
  }

  ActivityTimer? get nextTimer {
    if (isPreparing.value) {
      return timers.first;
    }
    if (currentIndex.value < timers.length - 1) {
      return timers[currentIndex.value + 1];
    }
    return loopEnabled.value ? timers.first : null;
  }

  @override
  void onInit() {
    super.onInit();
    loopEnabled.value = sequence.defaultLoopEnabled;

    if (sequence.preparationSeconds > 0) {
      isPreparing.value = true;
      _prepDurationMs = sequence.preparationSeconds * 1000;
      remainingMs.value = _prepDurationMs;
    } else {
      isPreparing.value = false;
      remainingMs.value = currentDurationMs;
    }
    start();
  }

  void start() {
    if (isCompleted.value) {
      return;
    }
    _deadline = _now().add(Duration(milliseconds: remainingMs.value));
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
    unawaited(WakelockPlus.enable());
    isRunning.value = true;
    unawaited(_syncBackgroundAlarms());
  }

  void pause() {
    remainingMs.value = math.max(0, remainingMsNow);
    _ticker?.cancel();
    _ticker = null;
    unawaited(WakelockPlus.disable());
    unawaited(_scheduler.cancelAll());
    isRunning.value = false;
  }

  void toggle() => isRunning.value ? pause() : start();

  /// The +15s / -15s controls: stretch the running deadline, or the stored
  /// remainder when paused. Never drops below one second.
  void addSeconds(int deltaSeconds) {
    final deltaMs = deltaSeconds * 1000;
    final deadline = _deadline;
    if (isRunning.value && deadline != null) {
      final extended = deadline.add(Duration(milliseconds: deltaMs));
      if (extended.isAfter(_now().add(const Duration(seconds: 1)))) {
        _deadline = extended;
      }
      remainingMs.value = math.max(0, remainingMsNow);
      unawaited(_syncBackgroundAlarms());
    } else {
      remainingMs.value = math.max(1000, remainingMs.value + deltaMs);
    }
  }

  void _tick() {
    if (!isRunning.value) {
      return;
    }
    final remaining = _deadline!.difference(_now()).inMilliseconds;

    if (remaining <= 0) {
      if (isPreparing.value) {
        _finishPreparation();
      } else {
        // The last step of a non-looping routine ends the session, and
        // _complete() owns that cue — so only intermediate boundaries get a
        // step alarm here. Completion is announced from one place, which
        // also covers a catch-up that crosses several boundaries at once.
        final endsSession =
            currentIndex.value == timers.length - 1 &&
            !(loopEnabled.value && sequence.totalDuration > 0);
        if (!endsSession) {
          unawaited(
            _cuePlayer.playAlarm(
              currentTimer.alarmSound ?? AppSettings().defaultAlarmSound,
            ),
          );
        }
        advance(overshootMs: -remaining);
      }
      return;
    }

    remainingMs.value = remaining;

    final secondsLeft = (remaining / 1000).ceil();
    if (secondsLeft <= 3 && secondsLeft != _lastHapticSecond) {
      _lastHapticSecond = secondsLeft;
      if (AppSettings().vibrationEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void _finishPreparation() {
    isPreparing.value = false;
    currentIndex.value = 0;
    remainingMs.value = currentDurationMs;
    _lastHapticSecond = -1;
    unawaited(_cuePlayer.playStart());
    _deadline = _now().add(Duration(milliseconds: remainingMs.value));
    unawaited(_syncBackgroundAlarms());
  }

  /// Moves to the next step, carrying any overshoot so a backgrounded
  /// routine catches up instead of drifting.
  void advance({int overshootMs = 0}) {
    var index = currentIndex.value;
    var carry = overshootMs;
    var loops = loopCount.value;

    final cycleMs = sequence.totalDuration * 1000;
    while (true) {
      if (index < timers.length - 1) {
        index++;
      } else if (loopEnabled.value && cycleMs > 0) {
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

      final durationMs = timers[index].durationInSeconds * 1000;
      if (carry < durationMs) {
        currentIndex.value = index;
        loopCount.value = loops;
        remainingMs.value = durationMs - carry;
        break;
      }
      carry -= durationMs;
    }

    _lastHapticSecond = -1;
    _deadline = _now().add(Duration(milliseconds: remainingMs.value));
    unawaited(_syncBackgroundAlarms());
  }

  void skipToNext() {
    if (isPreparing.value) {
      _finishPreparation();
      return;
    }
    if (currentIndex.value < timers.length - 1 || loopEnabled.value) {
      final wasRunning = isRunning.value;
      _ticker?.cancel();
      advance();
      if (wasRunning) {
        start();
      } else {
        _deadline = null;
        isRunning.value = false;
      }
    }
  }

  void goToPrevious() {
    if (isPreparing.value || currentIndex.value == 0) {
      return;
    }
    final wasRunning = isRunning.value;
    _ticker?.cancel();
    currentIndex.value -= 1;
    remainingMs.value = currentDurationMs;
    _lastHapticSecond = -1;
    isRunning.value = false;
    if (wasRunning) {
      start();
    }
  }

  void _complete() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_cuePlayer.playCompletion());
    unawaited(WakelockPlus.disable());
    unawaited(_scheduler.cancelAll());
    isRunning.value = false;
    isCompleted.value = true;
    _logSessionCompletion();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(WakelockPlus.disable());
    unawaited(_scheduler.cancelAll());
    isPreparing.value = sequence.preparationSeconds > 0;
    _prepDurationMs = sequence.preparationSeconds * 1000;
    currentIndex.value = 0;
    remainingMs.value = isPreparing.value ? _prepDurationMs : currentDurationMs;
    isRunning.value = false;
    isCompleted.value = false;
    loopCount.value = 0;
    _lastHapticSecond = -1;
    _deadline = null;
  }

  /// The loop toggle is the routine's saved preference, not just a switch
  /// for this run.
  void toggleLoop() {
    loopEnabled.value = !loopEnabled.value;
    sequence.defaultLoopEnabled = loopEnabled.value;
    unawaited(_persistLoop());
    unawaited(_syncBackgroundAlarms());
  }

  Future<void> _persistLoop() async {
    try {
      await _saveSequence(sequence);
    } catch (_) {
      // Non-fatal: the toggle still applies to the running session.
    }
  }

  Future<void> _syncBackgroundAlarms() async {
    if (!isRunning.value || isCompleted.value) {
      await _scheduler.cancelAll();
      return;
    }
    await _scheduler.ensurePermission();
    await _scheduler.schedule(pendingAlarms());
  }

  /// The boundaries still ahead, as wall-clock times. A looping routine only
  /// schedules the current pass; the list is refreshed whenever the session
  /// changes state, so the next lap is handed over when it begins.
  List<ScheduledAlarm> pendingAlarms() {
    final alarms = <ScheduledAlarm>[];
    var offsetMs = remainingMsNow;
    if (offsetMs <= 0) {
      return alarms;
    }
    final from = _now();

    if (isPreparing.value) {
      alarms.add(
        ScheduledAlarm(
          id: 0,
          at: from.add(Duration(milliseconds: offsetMs)),
          title: sequence.name,
          body: 'Get ready — starting ${timers.first.name}.',
          sound: _soundFor(0),
        ),
      );
    } else {
      alarms.add(
        ScheduledAlarm(
          id: currentIndex.value,
          at: from.add(Duration(milliseconds: offsetMs)),
          title: sequence.name,
          body: _bodyFor(currentIndex.value),
          sound: _soundFor(currentIndex.value),
          isCompletion: _endsSessionAt(currentIndex.value),
        ),
      );
      for (var i = currentIndex.value + 1; i < timers.length; i++) {
        offsetMs += timers[i].durationInSeconds * 1000;
        alarms.add(
          ScheduledAlarm(
            id: i + 1,
            at: from.add(Duration(milliseconds: offsetMs)),
            title: sequence.name,
            body: _bodyFor(i),
            sound: _soundFor(i),
            isCompletion: _endsSessionAt(i),
          ),
        );
      }
    }
    return alarms;
  }

  /// The cue that marks the end of step [index] — its own sound when it has
  /// one, the app default otherwise.
  AlarmSound _soundFor(int index) =>
      timers[index].alarmSound ?? AppSettings().defaultAlarmSound;

  bool _endsSessionAt(int index) =>
      index >= timers.length - 1 && !loopEnabled.value;

  String _bodyFor(int finishedIndex) =>
      finishedIndex >= timers.length - 1
          ? 'Routine complete.'
          : 'Next: ${timers[finishedIndex + 1].name}';

  void _logSessionCompletion() {
    try {
      unawaited(
        _logHistory(
          SessionHistory(
            title: sequence.name,
            totalDurationInSeconds:
                sequence.totalDuration * (loopCount.value + 1),
            itemCount: timers.length,
            loopCount: loopCount.value,
            sessionType: 'activity',
            category: sequence.category,
          ),
        ),
      );
    } catch (_) {
      // History is a nicety; a logging failure must not kill the session.
    }
  }

  @override
  void onClose() {
    _ticker?.cancel();
    unawaited(_cuePlayer.dispose());
    unawaited(_scheduler.cancelAll());
    unawaited(WakelockPlus.disable());
    super.onClose();
  }
}
