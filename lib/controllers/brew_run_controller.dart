import 'dart:async';

import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/brew_recipe.dart';
import '../services/alarm_scheduler.dart';
import '../services/cue_player.dart';

/// Runs a brew on the clock. Steps advance strictly by time; inside a pour
/// step the controller also reports whether the pour window is still open, so
/// the screen can say POUR then WAIT.
class BrewRunController extends GetxController {
  BrewRunController({
    required this.recipe,
    CuePlayer? cuePlayer,
    AlarmScheduler? scheduler,
    DateTime Function()? clock,
    this.tickInterval = const Duration(milliseconds: 200),
  }) : _cuePlayer = cuePlayer ?? AudioCuePlayer(),
       _scheduler = scheduler ?? LocalNotificationAlarmScheduler(),
       _now = clock ?? DateTime.now;

  final BrewRecipe recipe;
  final Duration tickInterval;

  final CuePlayer _cuePlayer;
  final AlarmScheduler _scheduler;
  final DateTime Function() _now;

  final RxInt stepIndex = 0.obs;
  final RxInt elapsedInStepMs = 0.obs;
  final RxBool isRunning = false.obs;
  final RxBool isFinished = false.obs;

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
  }

  void _tick() {
    final startedAt = _stepStartedAt;
    if (startedAt == null) {
      return;
    }
    elapsedInStepMs.value =
        _carriedMs + _now().difference(startedAt).inMilliseconds;

    while (!isFinished.value &&
        elapsedInStepMs.value >= currentStep.seconds * 1000) {
      final overflowMs = elapsedInStepMs.value - currentStep.seconds * 1000;

      if (stepIndex.value == recipe.steps.length - 1) {
        // The final boundary gets the dedicated completion alarm rather
        // than a step cue.
        unawaited(_cuePlayer.playCompletion());
        _finish();
        return;
      }
      unawaited(_cuePlayer.playAlarm(recipe.alarmSound));

      stepIndex.value += 1;
      _carriedMs = overflowMs;
      _stepStartedAt = _now();
      elapsedInStepMs.value = overflowMs;
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
