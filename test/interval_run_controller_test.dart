import 'package:activity_timer/controllers/interval_run_controller.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _Clock {
  _Clock(this.now);

  DateTime now;
}

/// 08:00 → 08:03 today, one alarm per minute: [08:00, 08:01, 08:02, 08:03].
IntervalTimer minuteTimer(DateTime day) => IntervalTimer(
  name: 'Stretch',
  startTime: DateTime(day.year, day.month, day.day, 8),
  endTime: DateTime(day.year, day.month, day.day, 8, 3),
  intervalValue: 1,
  intervalType: IntervalType.minute,
);

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

  // Anchor the fake clock on a fixed date; the controller normalizes the
  // schedule onto the clock's own day, so this stays deterministic.
  final day = DateTime(2026, 1, 1);

  final logged = <SessionHistory>[];

  setUp(logged.clear);

  (IntervalRunController, _RecordingCuePlayer, _Clock) makeController() {
    final clock = _Clock(DateTime(2026, 1, 1, 8, 0, 30));
    final cues = _RecordingCuePlayer();
    final controller = IntervalRunController(
      timer: minuteTimer(day),
      cuePlayer: cues,
      clock: () => clock.now,
      historyLogger: (history) async => logged.add(history),
      tickInterval: const Duration(milliseconds: 100),
    )..onInit();
    return (controller, cues, clock);
  }

  testWidgets('initializes the schedule and points at the next alarm', (
    tester,
  ) async {
    final (controller, cues, _) = makeController();

    expect(controller.allAlarmTimes.length, 4, reason: 'start + 3 intervals');
    expect(controller.currentAlarmIndex.value, 1);
    expect(controller.nextAlarmTime.value, DateTime(2026, 1, 1, 8, 1));
    expect(controller.isRunning.value, isTrue);
    expect(controller.isCompleted.value, isFalse);
    expect(cues.played, isEmpty);

    controller.onClose();
  });

  testWidgets('sounds a cue at each alarm boundary and advances', (
    tester,
  ) async {
    final (controller, cues, clock) = makeController();

    clock.now = DateTime(2026, 1, 1, 8, 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(cues.played, [AlarmSound.beep]);
    expect(controller.currentAlarmIndex.value, 2);
    expect(controller.nextAlarmTime.value, DateTime(2026, 1, 1, 8, 2));
    expect(cues.completedCount, 0, reason: 'not finished yet');

    controller.onClose();
  });

  testWidgets('catches up over several missed alarms, sounding once', (
    tester,
  ) async {
    final (controller, cues, clock) = makeController();

    // Two boundaries (08:01 and 08:02) passed while "backgrounded".
    clock.now = DateTime(2026, 1, 1, 8, 2, 30);
    await tester.pump(const Duration(milliseconds: 100));

    expect(cues.played.length, 1, reason: 'one cue for the whole catch-up');
    expect(controller.currentAlarmIndex.value, 3);

    controller.onClose();
  });

  testWidgets('the final boundary plays the dedicated completion alarm', (
    tester,
  ) async {
    final (controller, cues, clock) = makeController();

    clock.now = DateTime(2026, 1, 1, 8, 3, 5);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isCompleted.value, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(cues.completedCount, 1);
    expect(
      cues.played,
      isEmpty,
      reason: 'a catch-up ending in completion sounds only the completion',
    );

    // The ticker stops itself on completion; later frames change nothing.
    await tester.pump(const Duration(seconds: 1));
    expect(cues.completedCount, 1);

    expect(logged, hasLength(1), reason: 'the session lands in history');
    expect(logged.single.sessionType, 'interval');
    expect(logged.single.title, 'Stretch');

    controller.onClose();
  });

  testWidgets('toggle pauses the ticker and resumes it', (tester) async {
    final (controller, cues, clock) = makeController();

    controller.toggle();
    expect(controller.isRunning.value, isFalse);

    clock.now = DateTime(2026, 1, 1, 8, 1, 10);
    await tester.pump(const Duration(milliseconds: 300));
    expect(cues.played, isEmpty, reason: 'paused: no ticks, no cues');

    controller.toggle();
    expect(controller.isRunning.value, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(cues.played, [AlarmSound.beep], reason: 'resumed ticker catches up');

    controller.onClose();
  });

  testWidgets('skipToNext advances silently', (tester) async {
    final (controller, cues, _) = makeController();

    controller.skipToNext();

    expect(controller.currentAlarmIndex.value, 2);
    expect(cues.played, isEmpty);
    expect(cues.completedCount, 0);

    controller.onClose();
  });

  testWidgets('reset rebuilds the schedule from the clock', (tester) async {
    final (controller, cues, clock) = makeController();

    clock.now = DateTime(2026, 1, 1, 8, 3, 5);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.isCompleted.value, isTrue);

    clock.now = DateTime(2026, 1, 1, 8, 0, 30);
    controller.reset();

    expect(controller.isCompleted.value, isFalse);
    expect(controller.isRunning.value, isTrue);
    expect(controller.currentAlarmIndex.value, 1);
    expect(controller.nextAlarmTime.value, DateTime(2026, 1, 1, 8, 1));

    controller.onClose();
  });
}
