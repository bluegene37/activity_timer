// Gene - Nov, 8, 2026: Added unit and widget tests for Alert by Time, day-of-week recurrence, armed schedule switch, Quick Countdown Timer, Snooze (+1m/+5m), notification action buttons, and 3-2-1 / 50% audio cues.
// Gene - Nov, 16, 2026: Import GlowingTimerRing, IntervalTimerScreen, and TimerScreen for 1h+ circular loader tests.
import 'package:activity_timer/components/glowing_timer_ring.dart';
import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/controllers/interval_run_controller.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/screens/edit_interval_timer_screen.dart';
import 'package:activity_timer/screens/interval_timer_screen.dart';
import 'package:activity_timer/screens/timer_screen.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _PromptRecordingCuePlayer implements CuePlayer, PromptCuePlayer {
  final List<AlarmSound> alarms = [];
  int completions = 0;
  int starts = 0;
  int ticks = 0;
  int halfwayWarnings = 0;

  @override
  Future<void> playAlarm(AlarmSound sound) async => alarms.add(sound);

  @override
  Future<void> playCompletion() async => completions++;

  @override
  Future<void> playStart() async => starts++;

  @override
  Future<void> playCountdownTick() async => ticks++;

  @override
  Future<void> playHalfwayWarning() async => halfwayWarnings++;

  @override
  Future<void> dispose() async {}
}

class _RecordingAlarmScheduler implements AlarmScheduler {
  List<ScheduledAlarm> lastScheduled = const [];
  int cancelCount = 0;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {
    lastScheduled = List<ScheduledAlarm>.from(alarms);
  }

  @override
  Future<void> cancelAll() async {
    lastScheduled = const [];
    cancelCount++;
  }
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

  group('Alert by Time & Day-of-Week Recurrence', () {
    test(
      'point-in-time IntervalTimer produces a single alarm at startTime',
      () {
        final alertTime = DateTime(2026, 11, 8, 15, 30);
        final timer = IntervalTimer(
          name: 'Afternoon Standup',
          startTime: alertTime,
          endTime: alertTime,
          intervalValue: 1,
          intervalType: IntervalType.hour,
          isPointInTime: true,
          activeDays: const [1, 2, 3, 4, 5],
        );

        expect(timer.isPointInTime, isTrue);
        expect(timer.totalAlarms, 1);
        expect(timer.getAllAlarmTimes(), [alertTime]);
        expect(timer.shortIntervalString, 'Alert at time');
        expect(timer.recurrenceLabel, 'Weekdays');

        final roundTrip = IntervalTimer.fromJson(timer.toJson());
        expect(roundTrip.isPointInTime, isTrue);
        expect(roundTrip.activeDays, const [1, 2, 3, 4, 5]);
        expect(roundTrip.recurrenceLabel, 'Weekdays');
      },
    );

    test(
      'recurrenceLabel formats Every day, Weekdays, Weekends, One-time, and custom days',
      () {
        final now = DateTime(2026, 11, 8, 9);
        IntervalTimer withDays(List<int> days) => IntervalTimer(
          name: 'T',
          startTime: now,
          endTime: now,
          intervalValue: 1,
          intervalType: IntervalType.hour,
          isPointInTime: true,
          activeDays: days,
        );

        expect(withDays([1, 2, 3, 4, 5, 6, 7]).recurrenceLabel, 'Every day');
        expect(withDays([1, 2, 3, 4, 5]).recurrenceLabel, 'Weekdays');
        expect(withDays([6, 7]).recurrenceLabel, 'Weekends');
        expect(withDays([]).recurrenceLabel, 'One-time');
        expect(withDays([1, 3, 5]).recurrenceLabel, 'Mon, Wed, Fri');
      },
    );

    test(
      'IntervalRunController advances to next matching weekday in activeDays',
      () {
        // Nov 7, 2026 is a Saturday (weekday == 6).
        final saturdayMorning = DateTime(2026, 11, 7, 8, 0);
        final alertTime = DateTime(2026, 11, 7, 9, 30);
        final weekdayAlert = IntervalTimer(
          name: 'Morning Check-in',
          startTime: alertTime,
          endTime: alertTime,
          intervalValue: 1,
          intervalType: IntervalType.hour,
          isPointInTime: true,
          activeDays: const [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ],
        );

        final scheduler = _RecordingAlarmScheduler();
        final controller = IntervalRunController(
          timer: weekdayAlert,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: scheduler,
          clock: () => saturdayMorning,
          historyLogger: (_) async {},
        )..onInit();

        // Should shift from Saturday Nov 7 to Monday Nov 9 at 9:30 AM.
        expect(controller.nextAlarmTime.value, DateTime(2026, 11, 9, 9, 30));
        expect(controller.allAlarmTimes, [DateTime(2026, 11, 9, 9, 30)]);

        controller.onClose();
      },
    );

    testWidgets(
      'EditIntervalTimerScreen switches between Periodic Interval and Alert at Time',
      (tester) async {
        final now = DateTime(2026, 11, 8, 10, 0);
        final timer = IntervalTimer(
          name: 'New Interval Timer',
          startTime: now,
          endTime: now.add(const Duration(hours: 4)),
          intervalValue: 1,
          intervalType: IntervalType.hour,
        );

        await tester.pumpWidget(
          MaterialApp(home: EditIntervalTimerScreen(timer: timer, isNew: true)),
        );

        expect(find.text('Periodic Interval'), findsOneWidget);
        expect(find.text('Alert at Time'), findsOneWidget);
        expect(find.text('End Time'), findsOneWidget);

        await tester.tap(find.text('Alert at Time'));
        await tester.pumpAndSettle();

        // In Alert at Time mode, End Time is hidden and quick time preset chips are visible.
        expect(find.text('End Time'), findsNothing);
        expect(find.text('+15m'), findsOneWidget);
        expect(find.text('+30m'), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Weekdays'), findsOneWidget);
      },
    );
  });

  group('Snooze & Notification Action Buttons', () {
    testWidgets(
      'ActivityRunController.snooze re-arms a completed timer and schedules OS notification',
      (tester) async {
        var now = DateTime(2026, 11, 8, 10, 0);
        final scheduler = _RecordingAlarmScheduler();
        final cues = _PromptRecordingCuePlayer();
        final seq = TimerSequence(
          name: 'Quick Timer',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: '5m Sprint',
              durationInSeconds: 30,
              phase: IntervalPhase.work,
            ),
          ],
        );

        final controller = ActivityRunController(
          sequence: seq,
          cuePlayer: cues,
          scheduler: scheduler,
          clock: () => now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        )..onInit();

        now = now.add(const Duration(seconds: 31));
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.isCompleted.value, isTrue);

        // Snooze for 5 minutes.
        controller.snooze(const Duration(minutes: 5));
        await tester.pump();

        expect(controller.isCompleted.value, isFalse);
        expect(controller.isRunning.value, isTrue);
        expect(controller.remainingMs.value, 300000);
        expect(scheduler.lastScheduled, hasLength(1));
        expect(
          scheduler.lastScheduled.single.at,
          now.add(const Duration(minutes: 5)),
        );

        controller.onClose();
      },
    );

    test(
      'IntervalRunController.snooze re-arms a completed alert for 5 minutes',
      () async {
        var now = DateTime(2026, 11, 8, 15, 0);
        final scheduler = _RecordingAlarmScheduler();
        final alert = IntervalTimer(
          name: '3 PM Reminder',
          startTime: now,
          endTime: now,
          intervalValue: 1,
          intervalType: IntervalType.hour,
          isPointInTime: true,
        );

        final controller = IntervalRunController(
          timer: alert,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: scheduler,
          clock: () => now,
          historyLogger: (_) async {},
        )..onInit();

        now = now.add(const Duration(seconds: 5));
        controller.syncWithClock();
        expect(controller.isCompleted.value, isTrue);

        controller.snooze(const Duration(minutes: 5));
        expect(controller.isCompleted.value, isFalse);
        expect(controller.isRunning.value, isTrue);
        expect(
          controller.nextAlarmTime.value,
          now.add(const Duration(minutes: 5)),
        );

        controller.onClose();
      },
    );

    test(
      'LocalNotificationAlarmScheduler attaches Snooze 5m and Dismiss actions and handles actionId',
      () async {
        final scheduler = LocalNotificationAlarmScheduler();
        final details = scheduler.detailsForTesting(
          ScheduledAlarm(
            id: 1,
            at: DateTime(2026, 11, 8, 12),
            title: 'Timer',
            body: 'Done',
            sound: AlarmSound.beep,
            isCompletion: true,
          ),
        );

        final actions = details.android?.actions ?? const [];
        expect(
          actions.map((a) => a.id),
          containsAll([
            LocalNotificationAlarmScheduler.snooze5mActionId,
            LocalNotificationAlarmScheduler.dismissActionId,
          ]),
        );

        // Verify handlePayload with snooze_5m and dismiss_alarm on an active activity session.
        final now = DateTime(2026, 11, 8, 12);
        final seq = TimerSequence(
          name: 'Focus',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Work',
              durationInSeconds: 60,
              phase: IntervalPhase.work,
            ),
          ],
        );
        final session = ActivitySessionService();
        final controller = session.obtain(
          seq,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: _RecordingAlarmScheduler(),
          clock: () => now,
        );

        await LocalNotificationAlarmScheduler.handlePayload(
          'activity:${seq.id}',
          actionId: LocalNotificationAlarmScheduler.snooze5mActionId,
        );
        expect(controller.isRunning.value, isTrue);
        expect(controller.remainingMs.value, closeTo(300000, 1000));

        await LocalNotificationAlarmScheduler.handlePayload(
          'activity:${seq.id}',
          actionId: LocalNotificationAlarmScheduler.dismissActionId,
        );
        expect(session.active.value, isNull);

        IntervalSessionService().clear();
      },
    );
  });

  group('3-2-1 Countdown Beeps & 50% Halfway Warning Cue', () {
    testWidgets(
      'plays halfway warning at 50% and countdown ticks at 3, 2, 1 seconds',
      (tester) async {
        var now = DateTime(2026, 11, 8, 9, 0, 0);
        final cues = _PromptRecordingCuePlayer();
        final seq = TimerSequence(
          name: 'HIIT',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Plank',
              durationInSeconds: 20,
              phase: IntervalPhase.work,
            ),
          ],
        );

        await AppSettings().setCountdownBeepsEnabled(true);
        await AppSettings().setHalfwayWarningEnabled(true);

        final controller = ActivityRunController(
          sequence: seq,
          cuePlayer: cues,
          scheduler: NoopAlarmScheduler(),
          clock: () => now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        )..onInit();

        // Advance to 10s elapsed (50% of 20s).
        now = DateTime(2026, 11, 8, 9, 0, 10);
        await tester.pump(const Duration(milliseconds: 150));
        expect(cues.halfwayWarnings, 1);

        // Subsequent tick at 11s elapsed must not re-fire halfway warning.
        now = DateTime(2026, 11, 8, 9, 0, 11);
        await tester.pump(const Duration(milliseconds: 150));
        expect(cues.halfwayWarnings, 1);

        // Advance through 3s, 2s, 1s left.
        now = DateTime(2026, 11, 8, 9, 0, 17, 100); // ~2.9s left -> ceil = 3
        await tester.pump(const Duration(milliseconds: 150));
        now = DateTime(2026, 11, 8, 9, 0, 18, 100); // ~1.9s left -> ceil = 2
        await tester.pump(const Duration(milliseconds: 150));
        now = DateTime(2026, 11, 8, 9, 0, 19, 100); // ~0.9s left -> ceil = 1
        await tester.pump(const Duration(milliseconds: 150));

        expect(cues.ticks, 3);

        controller.onClose();
        await AppSettings().setHalfwayWarningEnabled(false);
      },
    );
  });

  // Gene - Nov, 16, 2026: Regression tests verifying 1h+ timers, pre-window intervals, and extended/snoozed steps drive both outer progress and the 60s pace ring.
  group('Long-Duration (1h+) Circular Loader Progress & Minute Sweep', () {
    testWidgets(
      '2-hour Alert at Time and 90-minute pre-window IntervalTimer advance outer progress and 60s pace ring',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var now = DateTime(2026, 11, 16, 10, 0, 0);
        final twoHourAlert = IntervalTimer(
          name: '2h Focus Alert',
          startTime: DateTime(2026, 11, 16, 12, 0, 0),
          endTime: DateTime(2026, 11, 16, 12, 0, 0),
          intervalValue: 1,
          intervalType: IntervalType.hour,
          isPointInTime: true,
        );

        final alertCtrl = IntervalRunController(
          timer: twoHourAlert,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: _RecordingAlarmScheduler(),
          clock: () => now,
          historyLogger: (_) async {},
        )..onInit();

        expect(alertCtrl.currentSegmentProgress, 0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: IntervalTimerScreen(
              timer: twoHourAlert,
              controller: alertCtrl,
            ),
          ),
        );
        await tester.pump();

        var ring = tester.widget<GlowingTimerRing>(
          find.byType(GlowingTimerRing),
        );
        expect(ring.progress, 0.0);
        expect(ring.secondaryProgress, 0.0);

        now = now.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 1));

        expect(alertCtrl.currentSegmentProgress, closeTo(10 / 7200, 1e-6));
        ring = tester.widget<GlowingTimerRing>(find.byType(GlowingTimerRing));
        expect(ring.progress, closeTo(10 / 7200, 1e-6));
        expect(ring.secondaryProgress, closeTo(10 / 60, 1e-6));

        alertCtrl.onClose();

        // 90-minute pre-window countdown before a 1-hour periodic interval begins.
        var preWindowNow = DateTime(2026, 11, 16, 10, 0, 0);
        final preWindowTimer = IntervalTimer(
          name: 'Afternoon Hourly',
          startTime: DateTime(2026, 11, 16, 11, 30, 0),
          endTime: DateTime(2026, 11, 16, 14, 30, 0),
          intervalValue: 1,
          intervalType: IntervalType.hour,
        );

        final preWindowCtrl = IntervalRunController(
          timer: preWindowTimer,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: _RecordingAlarmScheduler(),
          clock: () => preWindowNow,
          historyLogger: (_) async {},
        )..onInit();

        await tester.pumpWidget(
          MaterialApp(
            home: IntervalTimerScreen(
              key: const ValueKey('pre-window-interval'),
              timer: preWindowTimer,
              controller: preWindowCtrl,
            ),
          ),
        );
        await tester.pump();

        preWindowNow = preWindowNow.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 1));

        expect(preWindowCtrl.currentSegmentProgress, closeTo(10 / 5400, 1e-6));
        ring = tester.widget<GlowingTimerRing>(find.byType(GlowingTimerRing));
        expect(ring.progress, closeTo(10 / 5400, 1e-6));
        expect(ring.secondaryProgress, closeTo(10 / 60, 1e-6));

        preWindowCtrl.onClose();
      },
    );

    testWidgets(
      '90-minute Activity/Quick Timer, +5m extend, and 5m snooze keep progress and 60s pace ring active on TimerScreen',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var now = DateTime(2026, 11, 16, 10, 0, 0);
        final longSeq = TimerSequence(
          name: '90m Deep Work',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Focus',
              durationInSeconds: 5400,
              phase: IntervalPhase.work,
            ),
          ],
        );

        final longCtrl = ActivityRunController(
          sequence: longSeq,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: NoopAlarmScheduler(),
          clock: () => now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        )..onInit();

        await tester.pumpWidget(
          MaterialApp(
            home: TimerScreen(sequence: longSeq, controller: longCtrl),
          ),
        );
        await tester.pump();

        var ring = tester.widget<GlowingTimerRing>(
          find.byType(GlowingTimerRing),
        );
        expect(ring.progress, 0.0);
        expect(ring.secondaryProgress, 0.0);

        now = now.add(const Duration(seconds: 15));
        await tester.pump(const Duration(milliseconds: 150));

        ring = tester.widget<GlowingTimerRing>(find.byType(GlowingTimerRing));
        expect(ring.progress, closeTo(15 / 5400, 1e-6));
        expect(ring.secondaryProgress, closeTo(15 / 60, 1e-6));

        longCtrl.onClose();

        // Extending a 60s step by +5m (+300s) and snoozing by 5m expand currentDurationMs.
        var shortNow = DateTime(2026, 11, 16, 11, 0, 0);
        final shortSeq = TimerSequence(
          name: 'Extendable Timer',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Sprint',
              durationInSeconds: 60,
              phase: IntervalPhase.work,
            ),
          ],
        );

        final shortCtrl = ActivityRunController(
          sequence: shortSeq,
          cuePlayer: _PromptRecordingCuePlayer(),
          scheduler: NoopAlarmScheduler(),
          clock: () => shortNow,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        )..onInit();

        await tester.pumpWidget(
          MaterialApp(
            home: TimerScreen(
              key: const ValueKey('extendable-activity'),
              sequence: shortSeq,
              controller: shortCtrl,
            ),
          ),
        );
        await tester.pump();

        shortNow = shortNow.add(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 150));

        shortCtrl.addSeconds(300);
        await tester.pump();
        expect(shortCtrl.currentDurationMs, 350000);

        shortNow = shortNow.add(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 150));

        ring = tester.widget<GlowingTimerRing>(find.byType(GlowingTimerRing));
        expect(ring.progress, closeTo(10000 / 350000, 1e-5));
        expect(ring.secondaryProgress, isNotNull);

        shortCtrl.snooze(const Duration(minutes: 5));
        await tester.pump();
        expect(shortCtrl.currentDurationMs, 300000);

        shortNow = shortNow.add(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 150));

        ring = tester.widget<GlowingTimerRing>(find.byType(GlowingTimerRing));
        expect(ring.progress, closeTo(10000 / 300000, 1e-5));
        expect(ring.secondaryProgress, closeTo(10 / 60, 1e-5));

        shortCtrl.onClose();
      },
    );
  });
}
