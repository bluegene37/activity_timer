import 'dart:async';

import 'package:signals/signals_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/brew_recipe.dart';
import '../services/alarm_scheduler.dart';
import '../services/cue_player.dart';
// Gene - Nov, 7, 2026: Added DatabaseService import for active brew session persistence.
import '../services/database_service.dart';

/// Runs a brew on the clock. Steps advance strictly by time; inside a pour
/// step the controller also reports whether the pour window is still open, so
/// the screen can say POUR then WAIT.
class BrewRunController {
  BrewRunController({
    required this.recipe,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
    this.tickInterval = const Duration(milliseconds: 200),
  }) : _cuePlayer = cuePlayer ?? AudioCuePlayer(),
       _scheduler =
           scheduler ??
           LocalNotificationAlarmScheduler(
             idBase: LocalNotificationAlarmScheduler.brewIdBase,
           ),
       _now = clock ?? DateTime.now;

  final BrewRecipe recipe;
  final Duration tickInterval;

  final CuePlayer _cuePlayer;
  final AlarmScheduler _scheduler;
  final DateTime Function() _now;

  final stepIndex = signal(0);
  final elapsedInStepMs = signal(0);
  final isRunning = signal(false);
  final isFinished = signal(false);

  Timer? _ticker;
  DateTime? _stepStartedAt;
  int _carriedMs = 0;

  BrewStep get currentStep => recipe.steps[stepIndex.value];

  int? get currentTarget => recipe.targetGramsAt(stepIndex.value);

  int? get currentAdded => recipe.addedGramsAt(stepIndex.value);

  double? get currentRate => recipe.pourRateAt(stepIndex.value);

  /// True while the pour window of the current step is still open.
  bool get isPouring {
    final window = currentStep.pourSeconds;
    if (window == null || !currentStep.isPour) {
      return false;
    }
    return elapsedInStepMs.value < window * 1000;
  }

  Duration get stepRemaining => Duration(
    milliseconds: (currentStep.seconds * 1000 - elapsedInStepMs.value).clamp(
      0,
      1 << 30,
    ),
  );

  Duration get totalElapsed {
    var total = elapsedInStepMs.value;
    for (var i = 0; i < stepIndex.value; i++) {
      total += recipe.steps[i].seconds * 1000;
    }
    return Duration(milliseconds: total);
  }

  /// What the next step will ask for, e.g. 'pour to 320g' or 'Drawdown'.
  String? get nextStepLabel {
    final next = stepIndex.value + 1;
    if (next >= recipe.steps.length) {
      return null;
    }
    final target = recipe.targetGramsAt(next);
    return target == null ? recipe.steps[next].name : 'pour to ${target}g';
  }

  // Gene - Nov, 7, 2026: Preserved original start, pendingAlarms, pause, reset, _tick, and _finish implementations.
  // void start() {
  //   if (isFinished.value) {
  //     return;
  //   }
  //   _stepStartedAt = _now();
  //   _ticker?.cancel();
  //   _ticker = Timer.periodic(tickInterval, (_) => _tick());
  //   unawaited(WakelockPlus.enable());
  //   isRunning.value = true;
  //   unawaited(_syncBackgroundAlarms());
  // }
  //
  // /// Hands the remaining step boundaries to the OS so a brew keeps calling
  // /// the next pour even with the phone locked.
  // Future<void> _syncBackgroundAlarms() async {
  //   if (!isRunning.value || isFinished.value) {
  //     await _scheduler.cancelAll();
  //     return;
  //   }
  //   await _scheduler.ensurePermission();
  //   await _scheduler.schedule(pendingAlarms());
  // }
  //
  // /// The step boundaries still ahead, as wall-clock times. Exposed for tests.
  // List<ScheduledAlarm> pendingAlarms() {
  //   final alarms = <ScheduledAlarm>[];
  //   var offsetMs = currentStep.seconds * 1000 - elapsedInStepMs.value;
  //   final from = _now();
  //
  //   for (var i = stepIndex.value; i < recipe.steps.length; i++) {
  //     if (i > stepIndex.value) {
  //       offsetMs += recipe.steps[i].seconds * 1000;
  //     }
  //     final isLast = i == recipe.steps.length - 1;
  //     final nextTarget = isLast ? null : recipe.targetGramsAt(i + 1);
  //     alarms.add(
  //       ScheduledAlarm(
  //         id: i,
  //         at: from.add(Duration(milliseconds: offsetMs)),
  //         title: recipe.name,
  //         body:
  //             isLast
  //                 ? 'Brew complete.'
  //                 : (nextTarget == null
  //                     ? 'Next: ${recipe.steps[i + 1].name}'
  //                     : 'Next: pour to ${nextTarget}g'),
  //         sound: recipe.alarmSound,
  //         isCompletion: isLast,
  //       ),
  //     );
  //   }
  //   return alarms;
  // }
  //
  // void pause() {
  //   _carriedMs = elapsedInStepMs.value;
  //   _stepStartedAt = null;
  //   _ticker?.cancel();
  //   _ticker = null;
  //   unawaited(WakelockPlus.disable());
  //   isRunning.value = false;
  //   unawaited(_scheduler.cancelAll());
  // }
  //
  // void reset() {
  //   _ticker?.cancel();
  //   _ticker = null;
  //   _stepStartedAt = null;
  //   _carriedMs = 0;
  //   stepIndex.value = 0;
  //   elapsedInStepMs.value = 0;
  //   isRunning.value = false;
  //   isFinished.value = false;
  //   unawaited(WakelockPlus.disable());
  //   unawaited(_scheduler.cancelAll());
  // }
  //
  // void _tick() {
  //   final startedAt = _stepStartedAt;
  //   if (startedAt == null) {
  //     return;
  //   }
  //   elapsedInStepMs.value =
  //       _carriedMs + _now().difference(startedAt).inMilliseconds;
  //
  //   while (!isFinished.value &&
  //       elapsedInStepMs.value >= currentStep.seconds * 1000) {
  //     final overflowMs = elapsedInStepMs.value - currentStep.seconds * 1000;
  //
  //     if (stepIndex.value == recipe.steps.length - 1) {
  //       // The final boundary gets the dedicated completion alarm rather
  //       // than a step cue.
  //       unawaited(_cuePlayer.playCompletion());
  //       _finish();
  //       return;
  //     }
  //     unawaited(_cuePlayer.playAlarm(recipe.alarmSound));
  //
  //     stepIndex.value += 1;
  //     _carriedMs = overflowMs;
  //     _stepStartedAt = _now();
  //     elapsedInStepMs.value = overflowMs;
  //   }
  // }
  //
  // void _finish() {
  //   _ticker?.cancel();
  //   _ticker = null;
  //   _stepStartedAt = null;
  //   elapsedInStepMs.value = currentStep.seconds * 1000;
  //   isRunning.value = false;
  //   isFinished.value = true;
  //   unawaited(WakelockPlus.disable());
  //   unawaited(_scheduler.cancelAll());
  // }

  // Gene - Nov, 7, 2026: Added brew session persistence, notification payload, syncWithClock, and restoreFromSnapshot so running brew floaters survive backgrounding and notification taps.
  Future<void> persistSession() => _persistSession();

  Future<void> _persistSession() async {
    if (isFinished.value) {
      await DatabaseService().clearActiveBrewSession();
      return;
    }
    final data = <String, dynamic>{
      'recipeId': recipe.id,
      'recipeJson': recipe.toJson(),
      'stepIndex': stepIndex.value,
      'elapsedInStepMs': elapsedInStepMs.value,
      'carriedMs': _carriedMs,
      'stepStartedAtMs': _stepStartedAt?.millisecondsSinceEpoch,
      'isRunning': isRunning.value,
      'lastUpdatedMs': _now().millisecondsSinceEpoch,
    };
    try {
      await DatabaseService().saveActiveBrewSession(data);
    } catch (_) {}
  }

  // Gene - Nov, 8, 2026: Suspend the in-app periodic ticker when backgrounded so it never races and cancels OS notifications as they fire, and resume it cleanly in syncWithClock without re-playing already-fired cues.
  // void syncWithClock() {
  //   if (isRunning.value && !isFinished.value) {
  //     _tick();
  //   }
  // }
  void suspendTickerForBackground() {
    _ticker?.cancel();
    _ticker = null;
  }

  void syncWithClock() {
    if (isRunning.value && !isFinished.value) {
      _tick(playCue: false);
      if (isRunning.value && !isFinished.value && _ticker == null) {
        _ticker = Timer.periodic(tickInterval, (_) => _tick());
      }
    }
  }

  void start() {
    if (isFinished.value) {
      return;
    }
    _stepStartedAt = _now();
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
    unawaited(WakelockPlus.enable());
    isRunning.value = true;
    unawaited(_syncBackgroundAlarms());
    unawaited(_persistSession());
  }

  /// Hands the remaining step boundaries to the OS so a brew keeps calling
  /// the next pour even with the phone locked.
  Future<void> _syncBackgroundAlarms() async {
    if (!isRunning.value || isFinished.value) {
      await _scheduler.cancelAll();
      return;
    }
    await _scheduler.ensurePermission();
    await _scheduler.schedule(pendingAlarms());
  }

  /// The step boundaries still ahead, as wall-clock times. Exposed for tests.
  List<ScheduledAlarm> pendingAlarms() {
    final alarms = <ScheduledAlarm>[];
    var offsetMs = currentStep.seconds * 1000 - elapsedInStepMs.value;
    final from = _now();

    for (var i = stepIndex.value; i < recipe.steps.length; i++) {
      if (i > stepIndex.value) {
        offsetMs += recipe.steps[i].seconds * 1000;
      }
      final isLast = i == recipe.steps.length - 1;
      final nextTarget = isLast ? null : recipe.targetGramsAt(i + 1);
      alarms.add(
        ScheduledAlarm(
          id: i,
          at: from.add(Duration(milliseconds: offsetMs)),
          title: recipe.name,
          body:
              isLast
                  ? 'Brew complete.'
                  : (nextTarget == null
                      ? 'Next: ${recipe.steps[i + 1].name}'
                      : 'Next: pour to ${nextTarget}g'),
          sound: recipe.alarmSound,
          isCompletion: isLast,
          payload: 'brew:${recipe.id}',
        ),
      );
    }
    return alarms;
  }

  void pause() {
    _carriedMs = elapsedInStepMs.value;
    _stepStartedAt = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(WakelockPlus.disable());
    isRunning.value = false;
    unawaited(_scheduler.cancelAll());
    unawaited(_persistSession());
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _stepStartedAt = null;
    _carriedMs = 0;
    stepIndex.value = 0;
    elapsedInStepMs.value = 0;
    isRunning.value = false;
    isFinished.value = false;
    unawaited(WakelockPlus.disable());
    unawaited(_scheduler.cancelAll());
    unawaited(DatabaseService().clearActiveBrewSession());
  }

  // Gene - Nov, 8, 2026: Added playCue flag to _tick so background step catch-up does not double-play cues over OS notification sounds.
  // void _tick() {
  //   final startedAt = _stepStartedAt;
  //   if (startedAt == null) {
  //     return;
  //   }
  //   elapsedInStepMs.value =
  //       _carriedMs + _now().difference(startedAt).inMilliseconds;
  //
  //   var advancedStep = false;
  //   while (!isFinished.value &&
  //       elapsedInStepMs.value >= currentStep.seconds * 1000) {
  //     final overflowMs = elapsedInStepMs.value - currentStep.seconds * 1000;
  //
  //     if (stepIndex.value == recipe.steps.length - 1) {
  //       // The final boundary gets the dedicated completion alarm rather
  //       // than a step cue.
  //       unawaited(_cuePlayer.playCompletion());
  //       _finish();
  //       return;
  //     }
  //     unawaited(_cuePlayer.playAlarm(recipe.alarmSound));
  //
  //     stepIndex.value += 1;
  //     _carriedMs = overflowMs;
  //     _stepStartedAt = _now();
  //     elapsedInStepMs.value = overflowMs;
  //     advancedStep = true;
  //   }
  //   if (advancedStep) {
  //     unawaited(_persistSession());
  //   }
  // }
  void _tick({bool playCue = true}) {
    final startedAt = _stepStartedAt;
    if (startedAt == null) {
      return;
    }
    elapsedInStepMs.value =
        _carriedMs + _now().difference(startedAt).inMilliseconds;

    var advancedStep = false;
    while (!isFinished.value &&
        elapsedInStepMs.value >= currentStep.seconds * 1000) {
      final overflowMs = elapsedInStepMs.value - currentStep.seconds * 1000;

      if (stepIndex.value == recipe.steps.length - 1) {
        // The final boundary gets the dedicated completion alarm rather
        // than a step cue.
        if (playCue) {
          unawaited(_cuePlayer.playCompletion());
        }
        _finish();
        return;
      }
      if (playCue) {
        unawaited(_cuePlayer.playAlarm(recipe.alarmSound));
      }

      stepIndex.value += 1;
      _carriedMs = overflowMs;
      _stepStartedAt = _now();
      elapsedInStepMs.value = overflowMs;
      advancedStep = true;
    }
    if (advancedStep) {
      unawaited(_persistSession());
    }
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _stepStartedAt = null;
    elapsedInStepMs.value = currentStep.seconds * 1000;
    isRunning.value = false;
    isFinished.value = true;
    unawaited(WakelockPlus.disable());
    unawaited(_scheduler.cancelAll());
    unawaited(DatabaseService().clearActiveBrewSession());
  }

  void restoreFromSnapshot({
    required int initialStepIndex,
    required int savedElapsedInStepMs,
    required int savedCarriedMs,
    required int? stepStartedAtMs,
    required bool wasRunning,
  }) {
    stepIndex.value = initialStepIndex.clamp(0, recipe.steps.length - 1);
    if (!wasRunning) {
      _carriedMs = savedCarriedMs;
      elapsedInStepMs.value = savedElapsedInStepMs;
      isRunning.value = false;
      isFinished.value = false;
      return;
    }

    final now = _now();
    final startedAt =
        stepStartedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(stepStartedAtMs)
            : now;
    _carriedMs = savedCarriedMs;
    _stepStartedAt = startedAt;
    isRunning.value = true;
    // Gene - Nov, 8, 2026: Catch up elapsed brew steps silently on restore so OS notification audio is not duplicated.
    // _tick();
    _tick(playCue: false);
    if (!isFinished.value) {
      _ticker?.cancel();
      _ticker = Timer.periodic(tickInterval, (_) => _tick());
      unawaited(WakelockPlus.enable());
      unawaited(_syncBackgroundAlarms());
      unawaited(_persistSession());
    }
  }

  void onClose() {
    _ticker?.cancel();
    unawaited(_cuePlayer.dispose());
    unawaited(_scheduler.cancelAll());
    unawaited(WakelockPlus.disable());
  }
}
