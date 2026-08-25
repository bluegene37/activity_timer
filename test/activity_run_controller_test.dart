import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCuePlayer implements CuePlayer {
  final List<AlarmSound> alarms = [];
  int completions = 0;
  int starts = 0;

  @override
  Future<void> playAlarm(AlarmSound sound) async => alarms.add(sound);

  @override
  Future<void> playCompletion() async => completions++;

  @override
  Future<void> playStart() async => starts++;

  @override
  Future<void> dispose() async {}
}

class _Clock {
  _Clock(this.now);

  DateTime now;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );
  });

  TimerSequence sequence({int prep = 0, bool loop = false}) => TimerSequence(
    name: 'Gym',
    preparationSeconds: prep,
    defaultLoopEnabled: loop,
    timers: [
      ActivityTimer(
        name: 'Squats',
        durationInSeconds: 60,
        phase: IntervalPhase.work,
      ),
      ActivityTimer(
        name: 'Rest',
        durationInSeconds: 30,
        phase: IntervalPhase.rest,
      ),
    ],
  );

  final logged = <SessionHistory>[];
  final saved = <TimerSequence>[];

  setUp(() {
    logged.clear();
    saved.clear();
  });

  (ActivityRunController, _RecordingCuePlayer, _Clock) make({
    int prep = 0,
    bool loop = false,
  }) {
    final clock = _Clock(DateTime(2026, 1, 1, 8));
    final cues = _RecordingCuePlayer();
    final controller = ActivityRunController(
      sequence: sequence(prep: prep, loop: loop),
      cuePlayer: cues,
      scheduler: NoopAlarmScheduler(),
      clock: () => clock.now,
      historyLogger: (h) async => logged.add(h),
      sequenceSaver: (s) async => saved.add(s),
    )..onInit();
    return (controller, cues, clock);
  }

  testWidgets('starts running on the first step', (tester) async {
    final (controller, cues, _) = make();

    expect(controller.isRunning.value, isTrue);
    expect(controller.isPreparing.value, isFalse);
    expect(controller.currentTimer.name, 'Squats');
    expect(controller.remainingMs.value, 60000);
    expect(cues.alarms, isEmpty);

    controller.onClose();
  });

  testWidgets('a preparation countdown runs before the first step', (
    tester,
  ) async {
    final (controller, cues, clock) = make(prep: 5);

    expect(controller.isPreparing.value, isTrue);
    expect(controller.remainingMs.value, 5000);

    clock.now = DateTime(2026, 1, 1, 8, 0, 5);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isPreparing.value, isFalse);
    expect(cues.starts, 1, reason: 'the go tone marks the real start');
    expect(controller.currentTimer.name, 'Squats');

    controller.onClose();
  });

  testWidgets('a boundary sounds the step alarm and advances', (tester) async {
    final (controller, cues, clock) = make();

    clock.now = DateTime(2026, 1, 1, 8, 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.currentTimer.name, 'Rest');
    expect(cues.alarms, hasLength(1));
    expect(cues.completions, 0, reason: 'the routine is not over yet');

    controller.onClose();
  });

  testWidgets('the final step plays the completion alarm and logs history', (
    tester,
  ) async {
    final (controller, cues, clock) = make();

    clock.now = DateTime(2026, 1, 1, 8, 1, 31);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isCompleted.value, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(cues.completions, 1);
    expect(logged, hasLength(1));
    expect(logged.single.sessionType, 'activity');

    controller.onClose();
  });

  testWidgets('looping wraps to the first step instead of completing', (
    tester,
  ) async {
    final (controller, cues, clock) = make(loop: true);

    clock.now = DateTime(2026, 1, 1, 8, 1, 31);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isCompleted.value, isFalse);
    expect(controller.currentTimer.name, 'Squats');
    expect(controller.loopCount.value, 1);
    expect(cues.completions, 0, reason: 'a looping routine never completes');

    controller.onClose();
  });

  testWidgets('pause freezes the clock and resume carries on', (tester) async {
    final (controller, _, clock) = make();

    clock.now = DateTime(2026, 1, 1, 8, 0, 20);
    await tester.pump(const Duration(milliseconds: 100));
    controller.pause();
    final atPause = controller.remainingMs.value;

    // Time passes while paused; the remainder must not move.
    clock.now = DateTime(2026, 1, 1, 8, 0, 50);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.remainingMs.value, atPause);
    expect(controller.isRunning.value, isFalse);

    controller.start();
    expect(controller.isRunning.value, isTrue);

    controller.onClose();
  });

  testWidgets('addSeconds stretches the running deadline', (tester) async {
    final (controller, _, _) = make();

    controller.addSeconds(15);
    expect(controller.remainingMs.value, closeTo(75000, 50));

    controller.addSeconds(-15);
    expect(controller.remainingMs.value, closeTo(60000, 50));

    controller.onClose();
  });

  testWidgets('skip and previous move between steps', (tester) async {
    final (controller, cues, _) = make();

    controller.skipToNext();
    expect(controller.currentTimer.name, 'Rest');
    expect(cues.alarms, isEmpty, reason: 'skipping is silent');

    controller.goToPrevious();
    expect(controller.currentTimer.name, 'Squats');
    expect(controller.remainingMs.value, 60000);

    controller.onClose();
  });

  testWidgets('the loop toggle persists as the routine default', (
    tester,
  ) async {
    final (controller, _, _) = make();

    controller.toggleLoop();

    expect(controller.loopEnabled.value, isTrue);
    expect(controller.sequence.defaultLoopEnabled, isTrue);
    expect(saved, hasLength(1), reason: 'the routine must remember it loops');

    controller.onClose();
  });

  testWidgets('reset returns to the top without completing', (tester) async {
    final (controller, _, clock) = make();

    clock.now = DateTime(2026, 1, 1, 8, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.currentTimer.name, 'Rest');

    controller.reset();

    expect(controller.currentIndex.value, 0);
    expect(controller.isRunning.value, isFalse);
    expect(controller.isCompleted.value, isFalse);
    expect(controller.remainingMs.value, 60000);

    controller.onClose();
  });

  testWidgets('a routine saved with no steps still runs something', (
    tester,
  ) async {
    final controller = ActivityRunController(
      sequence: TimerSequence(name: 'Empty', timers: []),
      cuePlayer: _RecordingCuePlayer(),
      scheduler: NoopAlarmScheduler(),
      historyLogger: (_) async {},
      sequenceSaver: (_) async {},
    )..onInit();

    expect(controller.timers, hasLength(1));
    expect(controller.timers.single.durationInSeconds, 30);
    // TimerSequence defaults to a 5s preparation, so that is what runs first.
    expect(controller.isPreparing.value, isTrue);
    expect(controller.remainingMs.value, 5000);

    controller.onClose();
  });
}
