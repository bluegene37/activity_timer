// Regression: ISSUE-001 — concurrent activity, brew, and interval sessions
// all numbered their OS notifications from zero inside one shared id block,
// so a brew's step alarm silently replaced a running routine's.
// Regression: ISSUE-002 — an activity routine backgrounded during its
// preparation countdown handed the OS exactly one notification and then went
// silent for the rest of the session.
// Found by /qa on 2026-08-31
// Report: .gstack/qa-reports/qa-report-activity-timer-2026-08-31.md

import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
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

class _RecordingScheduler implements AlarmScheduler {
  final List<List<ScheduledAlarm>> scheduled = [];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async =>
      scheduled.add(alarms);

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
    // Reply successfully to the wakelock_plus pigeon channel.
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (message) async =>
          const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  group('ISSUE-001: one notification id block per session type', () {
    // The three session types run concurrently — MainNavigation shows a
    // floater for each — and every one of them numbers its alarms from zero.
    // Only the base keeps them apart.
    const size = LocalNotificationAlarmScheduler.idSpaceSize;
    const bases = <String, int>{
      'activity': LocalNotificationAlarmScheduler.activityIdBase,
      'brew': LocalNotificationAlarmScheduler.brewIdBase,
      'interval': LocalNotificationAlarmScheduler.intervalIdBase,
    };

    test('the blocks do not overlap', () {
      for (final a in bases.entries) {
        for (final b in bases.entries) {
          if (a.key == b.key) {
            continue;
          }
          expect(
            a.value < b.value + size && b.value < a.value + size,
            isFalse,
            reason: '${a.key} (${a.value}) overlaps ${b.key} (${b.value})',
          );
        }
      }
    });

    test('every base is distinct and the default is the activity block', () {
      expect(bases.values.toSet(), hasLength(3));
      expect(
        LocalNotificationAlarmScheduler().idBase,
        LocalNotificationAlarmScheduler.activityIdBase,
      );
      expect(
        LocalNotificationAlarmScheduler(
          idBase: LocalNotificationAlarmScheduler.brewIdBase,
        ).idBase,
        LocalNotificationAlarmScheduler.brewIdBase,
      );
    });
  });

  group('ISSUE-002: preparation countdown schedules the whole routine', () {
    TimerSequence buildSequence({required int prep}) => TimerSequence(
      name: 'Warmup',
      preparationSeconds: prep,
      timers: [
        ActivityTimer(
          name: 'Work',
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

    test('a routine pocketed during "get ready" still rings at every step', () {
      final scheduler = _RecordingScheduler();
      final start = DateTime(2026, 1, 1, 8);
      final controller = ActivityRunController(
        sequence: buildSequence(prep: 10),
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => start,
        historyLogger: (_) async {},
        sequenceSaver: (_) async {},
      )..onInit();

      expect(controller.isPreparing.value, isTrue);

      final alarms = controller.pendingAlarms();
      // The countdown, then both steps — not the countdown alone.
      expect(alarms, hasLength(3));
      expect(alarms.map((a) => a.id).toSet(), hasLength(3));
      expect(alarms[0].at, start.add(const Duration(seconds: 10)));
      expect(alarms[1].at, start.add(const Duration(seconds: 70)));
      expect(alarms[2].at, start.add(const Duration(seconds: 100)));
      expect(alarms[1].body, 'Next: Rest');
      expect(alarms.last.isCompletion, isTrue);
      expect(
        alarms.take(alarms.length - 1).every((a) => !a.isCompletion),
        isTrue,
      );

      controller.onClose();
    });

    test('the prep schedule matches what the run itself would schedule', () {
      final start = DateTime(2026, 1, 1, 8);
      final preparing = ActivityRunController(
        sequence: buildSequence(prep: 10),
        cuePlayer: _SilentCuePlayer(),
        scheduler: _RecordingScheduler(),
        clock: () => start,
        historyLogger: (_) async {},
        sequenceSaver: (_) async {},
      )..onInit();
      final running = ActivityRunController(
        sequence: buildSequence(prep: 0),
        cuePlayer: _SilentCuePlayer(),
        scheduler: _RecordingScheduler(),
        clock: () => start,
        historyLogger: (_) async {},
        sequenceSaver: (_) async {},
      )..onInit();

      // Drop the countdown alarm and the two lists describe the same routine.
      final afterPrep = preparing.pendingAlarms().skip(1).toList();
      final direct = running.pendingAlarms();
      expect(afterPrep.map((a) => a.body), direct.map((a) => a.body));
      expect(
        afterPrep.map((a) => a.isCompletion),
        direct.map((a) => a.isCompletion),
      );

      preparing.onClose();
      running.onClose();
    });

    test('a routine with no countdown is unchanged', () {
      final controller = ActivityRunController(
        sequence: buildSequence(prep: 0),
        cuePlayer: _SilentCuePlayer(),
        scheduler: _RecordingScheduler(),
        clock: () => DateTime(2026, 1, 1, 8),
        historyLogger: (_) async {},
        sequenceSaver: (_) async {},
      )..onInit();

      expect(controller.isPreparing.value, isFalse);
      expect(controller.pendingAlarms(), hasLength(2));

      controller.onClose();
    });
  });
}
