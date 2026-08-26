import 'dart:async';

import 'package:signals/signals_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/interval_timer.dart';
import '../models/session_history.dart';
import '../services/alarm_scheduler.dart';
import '../services/cue_player.dart';
import '../services/database_service.dart';

/// Runs an interval timer on the wall clock, decoupled from any screen.
///
/// This is the engine that used to live inside `IntervalTimerScreen`:
/// normalizing the start/end window to today, ticking once a second, sounding
/// a cue at every alarm boundary, and logging the session when the last alarm
/// fires. Owning it here (via `IntervalSessionService`) lets the screen be
/// popped — minimized — without stopping the schedule.
class IntervalRunController {
  IntervalRunController({
    required this.timer,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
    Future<void> Function(SessionHistory)? historyLogger,
    this.tickInterval = const Duration(seconds: 1),
  }) : _cuePlayer = cuePlayer ?? AudioCuePlayer(),
       _scheduler = scheduler ?? LocalNotificationAlarmScheduler(),
       _now = clock ?? DateTime.now,
       _logHistory =
           historyLogger ??
           ((history) => DatabaseService().logSessionHistory(history));

  final IntervalTimer timer;
  final Duration tickInterval;

  final CuePlayer _cuePlayer;
  final AlarmScheduler _scheduler;
  final DateTime Function() _now;
  final Future<void> Function(SessionHistory) _logHistory;

  late final currentTime = signal(_now());
  late final nextAlarmTime = signal(_now());
  final currentAlarmIndex = signal(0);
  final isRunning = signal(true);
  final isCompleted = signal(false);

  /// Today's full alarm schedule, computed once per (re)initialization.
  List<DateTime> allAlarmTimes = const [];

  Timer? _ticker;

  Duration get untilNextAlarm {
    final difference = nextAlarmTime.value.difference(currentTime.value);
    return difference.isNegative ? Duration.zero : difference;
  }

  void onInit() {
    _initialize();
    _startTicker();
    unawaited(_syncBackgroundAlarms());
  }

  /// Hands every future alarm to the OS so a locked phone still rings, and
  /// withdraws them the moment the session stops being live.
  Future<void> _syncBackgroundAlarms() async {
    if (!isRunning.value || isCompleted.value) {
      await _scheduler.cancelAll();
      return;
    }
    await _scheduler.ensurePermission();
    await _scheduler.schedule(pendingAlarms());
  }

  /// The alarms still ahead of the current position, as the OS should see
  /// them. Exposed for tests.
  List<ScheduledAlarm> pendingAlarms() {
    final alarms = <ScheduledAlarm>[];
    for (var i = currentAlarmIndex.value; i < allAlarmTimes.length; i++) {
      final isLast = i == allAlarmTimes.length - 1;
      alarms.add(
        ScheduledAlarm(
          id: i,
          at: allAlarmTimes[i],
          title: timer.name,
          body:
              isLast
                  ? 'Final alarm — the schedule is complete.'
                  : 'Alarm ${i + 1} of ${allAlarmTimes.length}',
          sound: timer.alarmSound,
          isCompletion: isLast,
        ),
      );
    }
    return alarms;
  }

  void _initialize() {
    final now = _now();
    currentTime.value = now;

    // Normalize start and end times to the current day.
    DateTime normalizedStart = DateTime(
      now.year,
      now.month,
      now.day,
      timer.startTime.hour,
      timer.startTime.minute,
      timer.startTime.second,
    );

    DateTime normalizedEnd = DateTime(
      now.year,
      now.month,
      now.day,
      timer.endTime.hour,
      timer.endTime.minute,
      timer.endTime.second,
    );

    // A range whose end precedes its start crosses midnight: push the end
    // to the next day.
    if (normalizedEnd.isBefore(normalizedStart)) {
      normalizedEnd = normalizedEnd.add(const Duration(days: 1));
    }

    // If the entire window is in the past, shift it to the next day.
    if (now.isAfter(normalizedEnd)) {
      normalizedStart = normalizedStart.add(const Duration(days: 1));
      normalizedEnd = normalizedEnd.add(const Duration(days: 1));
    }

    // A temporary timer model with normalized dates computes the schedule.
    final tempTimer = IntervalTimer(
      id: timer.id,
      name: timer.name,
      startTime: normalizedStart,
      endTime: normalizedEnd,
      intervalValue: timer.intervalValue,
      intervalType: timer.intervalType,
    );

    allAlarmTimes = tempTimer.getAllAlarmTimes();

    if (now.isBefore(normalizedStart)) {
      // Before the window opens the first alarm is the start itself.
      nextAlarmTime.value = normalizedStart;
      currentAlarmIndex.value = 0;
    } else if (now.isAfter(normalizedEnd)) {
      // Unreachable given the normalization above, but kept for safety.
      nextAlarmTime.value = normalizedEnd;
      currentAlarmIndex.value = allAlarmTimes.length - 1;
      isCompleted.value = true;
    } else {
      nextAlarmTime.value = tempTimer.getNextAlarmTime(now);
      currentAlarmIndex.value = allAlarmTimes.indexWhere(
        (time) => time.isAtSameMomentAs(nextAlarmTime.value),
      );

      if (currentAlarmIndex.value == -1) {
        // No exact match: the closest future alarm, or done.
        currentAlarmIndex.value = allAlarmTimes.indexWhere(
          (time) => time.isAfter(now),
        );
        if (currentAlarmIndex.value == -1) {
          currentAlarmIndex.value = allAlarmTimes.length - 1;
          isCompleted.value = true;
        } else {
          nextAlarmTime.value = allAlarmTimes[currentAlarmIndex.value];
        }
      }
    }
  }

  void _startTicker() {
    unawaited(WakelockPlus.enable());
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _tick() {
    currentTime.value = _now();
    if (isCompleted.value || currentTime.value.isBefore(nextAlarmTime.value)) {
      return;
    }
    // Advance past every alarm that already elapsed (several may have passed
    // at once if the app was backgrounded), sounding only once — the
    // dedicated completion alarm when the schedule just ended, a step cue
    // otherwise.
    while (!isCompleted.value &&
        !currentTime.value.isBefore(nextAlarmTime.value)) {
      _advance();
    }
    if (isCompleted.value) {
      unawaited(_cuePlayer.playCompletion());
    } else {
      unawaited(_cuePlayer.playAlarm(timer.alarmSound));
    }
  }

  void _advance() {
    if (currentAlarmIndex.value < allAlarmTimes.length - 1) {
      currentAlarmIndex.value += 1;
      nextAlarmTime.value = allAlarmTimes[currentAlarmIndex.value];
    } else {
      isCompleted.value = true;
      isRunning.value = false;
      _ticker?.cancel();
      _ticker = null;
      unawaited(WakelockPlus.disable());
      unawaited(_scheduler.cancelAll());
      _logSessionCompletion();
    }
  }

  /// The forward button: silently skip to the next alarm.
  void skipToNext() {
    _advance();
    unawaited(_syncBackgroundAlarms());
  }

  void toggle() {
    if (isCompleted.value) {
      return;
    }
    if (isRunning.value) {
      _ticker?.cancel();
      _ticker = null;
      unawaited(WakelockPlus.disable());
    } else {
      _startTicker();
    }
    isRunning.value = !isRunning.value;
    unawaited(_syncBackgroundAlarms());
  }

  void reset() {
    _ticker?.cancel();
    isCompleted.value = false;
    isRunning.value = true;
    _initialize();
    _startTicker();
    unawaited(_syncBackgroundAlarms());
  }

  void _logSessionCompletion() {
    final durationInSeconds =
        allAlarmTimes.last.difference(allAlarmTimes.first).inSeconds;
    try {
      unawaited(
        _logHistory(
          SessionHistory(
            title: timer.name,
            totalDurationInSeconds:
                durationInSeconds > 0 ? durationInSeconds : 60,
            itemCount: allAlarmTimes.length,
            loopCount: 0,
            sessionType: 'interval',
          ),
        ),
      );
    } catch (_) {
      // History is a nicety; a logging failure must not kill the alarm flow.
    }
  }

  void onClose() {
    _ticker?.cancel();
    unawaited(_cuePlayer.dispose());
    unawaited(_scheduler.cancelAll());
    unawaited(WakelockPlus.disable());
  }
}
