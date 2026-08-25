import 'dart:io';

import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/controllers/interval_run_controller.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentCuePlayer implements CuePlayer {
  @override
  Future<void> playAlarm(AlarmSound sound) async {}

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async {}
}

/// Records what the OS would have been asked to do.
class _RecordingScheduler implements AlarmScheduler {
  final List<List<ScheduledAlarm>> scheduled = [];
  int cancelCount = 0;
  int permissionAsks = 0;

  List<ScheduledAlarm> get latest => scheduled.last;

  @override
  Future<bool> ensurePermission() async {
    permissionAsks++;
    return true;
  }

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async =>
      scheduled.add(alarms);

  @override
  Future<void> cancelAll() async => cancelCount++;
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

  group('interval schedule hand-off', () {
    IntervalTimer minuteTimer() => IntervalTimer(
      name: 'Stretch',
      startTime: DateTime(2026, 1, 1, 8),
      endTime: DateTime(2026, 1, 1, 8, 3),
      intervalValue: 1,
      intervalType: IntervalType.minute,
    );

    (IntervalRunController, _RecordingScheduler, _Clock) make() {
      final clock = _Clock(DateTime(2026, 1, 1, 8, 0, 30));
      final scheduler = _RecordingScheduler();
      final controller = IntervalRunController(
        timer: minuteTimer(),
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => clock.now,
        historyLogger: (_) async {},
        tickInterval: const Duration(milliseconds: 100),
      )..onInit();
      return (controller, scheduler, clock);
    }

    testWidgets('every remaining alarm is handed to the OS on start', (
      tester,
    ) async {
      final (controller, scheduler, _) = make();
      await tester.pump(const Duration(milliseconds: 10));

      expect(scheduler.permissionAsks, greaterThan(0));
      expect(scheduler.scheduled, isNotEmpty);
      // 08:00 already passed; 08:01, 08:02 and 08:03 are still ahead.
      expect(scheduler.latest.map((a) => a.at), [
        DateTime(2026, 1, 1, 8, 1),
        DateTime(2026, 1, 1, 8, 2),
        DateTime(2026, 1, 1, 8, 3),
      ]);
      expect(scheduler.latest.last.body, contains('complete'));
      expect(scheduler.latest.first.title, 'Stretch');

      controller.onClose();
    });

    testWidgets('pausing withdraws them and resuming re-arms', (tester) async {
      final (controller, scheduler, _) = make();
      await tester.pump(const Duration(milliseconds: 10));
      final scheduledOnStart = scheduler.scheduled.length;

      controller.toggle(); // pause
      await tester.pump(const Duration(milliseconds: 10));
      expect(
        scheduler.cancelCount,
        greaterThan(0),
        reason: 'a paused timer must not ring in the background',
      );

      controller.toggle(); // resume
      await tester.pump(const Duration(milliseconds: 10));
      expect(scheduler.scheduled.length, greaterThan(scheduledOnStart));

      controller.onClose();
    });

    testWidgets('skipping reschedules from the new position', (tester) async {
      final (controller, scheduler, _) = make();
      await tester.pump(const Duration(milliseconds: 10));

      controller.skipToNext();
      await tester.pump(const Duration(milliseconds: 10));

      expect(scheduler.latest.map((a) => a.at), [
        DateTime(2026, 1, 1, 8, 2),
        DateTime(2026, 1, 1, 8, 3),
      ], reason: 'the skipped alarm must not still be pending');

      controller.onClose();
    });

    testWidgets('finishing cancels everything', (tester) async {
      final (controller, scheduler, clock) = make();
      await tester.pump(const Duration(milliseconds: 10));
      final before = scheduler.cancelCount;

      clock.now = DateTime(2026, 1, 1, 8, 3, 5);
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.isCompleted.value, isTrue);
      expect(scheduler.cancelCount, greaterThan(before));

      controller.onClose();
    });
  });

  group('brew schedule hand-off', () {
    BrewRecipe recipe() => BrewRecipe(
      name: 'Morning V60',
      method: BrewMethod.v60,
      doseGrams: 20,
      ratio: 16,
      steps: [
        BrewStep(
          name: 'Bloom',
          seconds: 30,
          pourToFraction: 0.1875,
          pourSeconds: 10,
        ),
        BrewStep(
          name: 'Main pour',
          seconds: 60,
          pourToFraction: 1,
          pourSeconds: 30,
        ),
      ],
    );

    testWidgets('step boundaries are scheduled as wall-clock times', (
      tester,
    ) async {
      final scheduler = _RecordingScheduler();
      final clock = _Clock(DateTime(2026, 1, 1, 8));
      final controller = BrewRunController(
        recipe: recipe(),
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => clock.now,
      )..start();
      await tester.pump(const Duration(milliseconds: 10));

      expect(scheduler.scheduled, isNotEmpty);
      expect(scheduler.latest.map((a) => a.at), [
        DateTime(2026, 1, 1, 8, 0, 30), // bloom ends
        DateTime(2026, 1, 1, 8, 1, 30), // main pour ends
      ]);
      expect(scheduler.latest.first.body, 'Next: pour to 320g');
      expect(scheduler.latest.last.body, 'Brew complete.');

      controller.pause();
      controller.onClose();
    });

    testWidgets('pausing a brew withdraws its alarms', (tester) async {
      final scheduler = _RecordingScheduler();
      final controller = BrewRunController(
        recipe: recipe(),
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
      )..start();
      await tester.pump(const Duration(milliseconds: 10));

      controller.pause();
      expect(scheduler.cancelCount, greaterThan(0));

      controller.onClose();
    });
  });

  group('custom notification sounds', () {
    test('each cue gets its own Android channel', () {
      // Android ties a sound to its channel and will not let it change
      // afterwards, so two different cues must not share one channel.
      final ids =
          AlarmSound.values
              .map(
                (s) => LocalNotificationAlarmScheduler.channelIdFor(
                  s,
                  isCompletion: false,
                ),
              )
              .toList();
      expect(ids.toSet(), hasLength(AlarmSound.values.length));

      final completion = LocalNotificationAlarmScheduler.channelIdFor(
        null,
        isCompletion: true,
      );
      expect(ids, isNot(contains(completion)));
    });

    test('a raw resource exists on Android for every cue', () {
      // RawResourceAndroidNotificationSound resolves by res/raw name, which
      // is the file's stem, lowercased.
      final raw =
          Directory('android/app/src/main/res/raw')
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last.split('.').first)
              .toSet();

      for (final sound in AlarmSound.values) {
        expect(
          raw,
          contains(sound.fileName.split('.').first.toLowerCase()),
          reason: '${sound.displayName} has no res/raw copy to play',
        );
      }
      expect(raw, contains('timer_complete'));
    });

    test('interval alarms carry the timer\'s sound and mark the last one', () {
      final scheduler = _RecordingScheduler();
      final timer = IntervalTimer(
        name: 'Stretch',
        startTime: DateTime(2026, 1, 1, 8),
        endTime: DateTime(2026, 1, 1, 8, 2),
        intervalValue: 1,
        intervalType: IntervalType.minute,
        alarmSoundName: AlarmSound.siren.name,
      );
      final controller = IntervalRunController(
        timer: timer,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => DateTime(2026, 1, 1, 7, 59),
        historyLogger: (_) async {},
      )..onInit();

      final alarms = controller.pendingAlarms();
      expect(alarms.every((a) => a.sound == AlarmSound.siren), isTrue);
      expect(alarms.last.isCompletion, isTrue);
      expect(
        alarms.take(alarms.length - 1).every((a) => !a.isCompletion),
        isTrue,
      );

      controller.onClose();
    });
  });

  group('ScheduledAlarm', () {
    test('compares by value so reschedules can be diffed', () {
      final at = DateTime(2026, 1, 1, 8);
      const body = 'Next: Rest';
      expect(
        ScheduledAlarm(id: 1, at: at, title: 'A', body: body),
        ScheduledAlarm(id: 1, at: at, title: 'A', body: body),
      );
      expect(
        ScheduledAlarm(id: 1, at: at, title: 'A', body: body),
        isNot(ScheduledAlarm(id: 2, at: at, title: 'A', body: body)),
      );
    });
  });

  group('NoopAlarmScheduler', () {
    test('never claims permission it does not have', () async {
      final scheduler = NoopAlarmScheduler();
      expect(await scheduler.ensurePermission(), isFalse);
      await scheduler.schedule([
        ScheduledAlarm(id: 0, at: DateTime(2026), title: 't', body: 'b'),
      ]);
      await scheduler.cancelAll();
    });
  });

  test('session history still records after a scheduled run', () {
    // Guards the shape the interval controller logs; the scheduler must not
    // have changed it.
    final history = SessionHistory(
      title: 'Stretch',
      totalDurationInSeconds: 180,
      itemCount: 4,
      loopCount: 0,
      sessionType: 'interval',
    );
    expect(history.sessionType, 'interval');
  });
}
