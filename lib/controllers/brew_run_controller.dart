import 'dart:async';

import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/brew_recipe.dart';
import '../services/brew_cue_player.dart';

/// Runs a brew on the clock. Steps advance strictly by time; inside a pour
/// step the controller also reports whether the pour window is still open, so
/// the screen can say POUR then WAIT.
class BrewRunController extends GetxController {
  BrewRunController({
    required this.recipe,
    BrewCuePlayer? cuePlayer,
    DateTime Function()? clock,
    this.tickInterval = const Duration(milliseconds: 200),
  }) : _cuePlayer = cuePlayer ?? AudioBrewCuePlayer(),
       _now = clock ?? DateTime.now;

  final BrewRecipe recipe;
  final Duration tickInterval;

  final BrewCuePlayer _cuePlayer;
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
    milliseconds:
        (currentStep.seconds * 1000 - elapsedInStepMs.value).clamp(0, 1 << 30),
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
  }

  void pause() {
    _carriedMs = elapsedInStepMs.value;
    _stepStartedAt = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(WakelockPlus.disable());
    isRunning.value = false;
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
      unawaited(_cuePlayer.playStepEnd(recipe.alarmSound));

      if (stepIndex.value == recipe.steps.length - 1) {
        _finish();
        return;
      }

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
  }

  @override
  void onClose() {
    _ticker?.cancel();
    unawaited(_cuePlayer.dispose());
    unawaited(WakelockPlus.disable());
    super.onClose();
  }
}
