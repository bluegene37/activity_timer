import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock {
  DateTime value = DateTime(2026, 1, 1, 8);

  DateTime call() => value;

  void advance(Duration delta) => value = value.add(delta);
}

class _RecordingCuePlayer implements CuePlayer {
  final List<AlarmSound> played = [];
  int completedCount = 0;

  @override
  Future<void> playAlarm(AlarmSound sound) async => played.add(sound);

  @override
  Future<void> playCompletion() async => completedCount++;

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async {}
}

BrewRecipe threeStepBrew() => BrewRecipe(
  name: 'Test brew',
  method: BrewMethod.v60,
  doseGrams: 20,
  ratio: 16,
  alarmSoundName: AlarmSound.bell.name,
  steps: [
    BrewStep(name: 'Bloom', seconds: 30, pourToFraction: 0.1875, pourSeconds: 10),
    BrewStep(name: 'Main pour', seconds: 30, pourToFraction: 1, pourSeconds: 15),
    BrewStep(name: 'Drawdown', seconds: 20, kind: BrewStepKind.drawdown),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Reply successfully to the wakelock_plus pigeon channel so the
    // controller's WakelockPlus.enable/disable calls don't throw in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );
  });

  /// Advances the injected clock and the fake-async timer queue together.
  Future<void> advance(
    WidgetTester tester,
    _FakeClock clock,
    Duration delta,
  ) async {
    clock.advance(delta);
    await tester.pump(delta);
  }

  testWidgets('starts on the first step showing its target and rate', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: threeStepBrew(),
      clock: clock.call,
      cuePlayer: _RecordingCuePlayer(),
    );
    addTearDown(controller.reset);

    controller.start();

    expect(controller.stepIndex.value, 0);
    expect(controller.currentTarget, 60);
    expect(controller.currentAdded, 60);
    expect(controller.currentRate, 6);
    expect(controller.isPouring, isTrue);
    expect(controller.nextStepLabel, 'pour to 320g');

    // flutter_test checks for pending Timers as soon as the test body
    // returns, before addTearDown callbacks run (that ordering only
    // cancels timers early for widgets disposed via the widget tree).
    // Stop the ticker explicitly so the still-running periodic Timer
    // doesn't trip that check.
    controller.reset();
  });

  testWidgets('flips from POUR to WAIT when the pour window closes', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: threeStepBrew(),
      clock: clock.call,
      cuePlayer: _RecordingCuePlayer(),
    );
    addTearDown(controller.reset);

    controller.start();
    await advance(tester, clock, const Duration(seconds: 9));
    expect(controller.isPouring, isTrue);

    await advance(tester, clock, const Duration(seconds: 2));
    expect(controller.isPouring, isFalse, reason: '10s pour window has closed');
    expect(controller.stepIndex.value, 0, reason: 'the step itself is still running');

    controller.reset();
  });

  testWidgets('advances at the step boundary and plays the cue', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final clock = _FakeClock();
    final cues = _RecordingCuePlayer();
    final controller = BrewRunController(
      recipe: threeStepBrew(),
      clock: clock.call,
      cuePlayer: cues,
    );
    addTearDown(controller.reset);

    controller.start();
    await advance(tester, clock, const Duration(seconds: 30));

    expect(controller.stepIndex.value, 1);
    expect(controller.currentTarget, 320);
    expect(cues.played, [AlarmSound.bell]);
    expect(cues.completedCount, 0, reason: 'not finished yet');

    controller.reset();
  });

  testWidgets('finishes after the last step and stops ticking', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final clock = _FakeClock();
    final cues = _RecordingCuePlayer();
    final controller = BrewRunController(
      recipe: threeStepBrew(),
      clock: clock.call,
      cuePlayer: cues,
    );
    addTearDown(controller.reset);

    controller.start();
    await advance(tester, clock, const Duration(seconds: 80));

    expect(controller.isFinished.value, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(cues.played.length, 2, reason: 'one cue per intermediate boundary');
    expect(
      cues.completedCount,
      1,
      reason: 'the final boundary plays the dedicated completion alarm',
    );
  });

  testWidgets('pause freezes elapsed time and resume continues from there', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final clock = _FakeClock();
    final controller = BrewRunController(
      recipe: threeStepBrew(),
      clock: clock.call,
      cuePlayer: _RecordingCuePlayer(),
    );
    addTearDown(controller.reset);

    controller.start();
    await advance(tester, clock, const Duration(seconds: 5));
    controller.pause();

    await advance(tester, clock, const Duration(seconds: 20));
    expect(controller.stepIndex.value, 0);
    expect(controller.stepRemaining.inSeconds, 25);

    controller.start();
    await advance(tester, clock, const Duration(seconds: 25));
    expect(controller.stepIndex.value, 1);

    controller.reset();
  });
}
