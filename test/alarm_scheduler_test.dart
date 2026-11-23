import 'dart:io';

// Gene - Nov, 15, 2026: Added ActivityRunController and timezone imports for background alarm scheduling regression tests.
import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/controllers/interval_run_controller.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:flutter/services.dart';
// Gene - Nov, 8, 2026: Added flutter_local_notifications import to verify Android/iOS notification sound and banner details.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

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

    // Gene - Nov, 8, 2026: Ensure R8 resource shrinking is prevented from stripping raw notification sounds in release builds, and platform notification details explicitly enable sound and banner presentation.
    test(
      'android/app/src/main/res/raw/keep.xml preserves @raw/* from R8 resource shrinking',
      () {
        final keepFile = File('android/app/src/main/res/raw/keep.xml');
        expect(
          keepFile.existsSync(),
          isTrue,
          reason:
              'Without keep.xml, R8 shrinkResources strips dynamically-referenced res/raw sound files to 0 bytes in release builds.',
        );
        final contents = keepFile.readAsStringSync();
        expect(contents, contains('tools:keep'));
        expect(contents, contains('@raw/*'));
      },
    );

    test(
      'platform NotificationDetails explicitly enable sound and banner presentation for every cue and completion',
      () {
        final scheduler = LocalNotificationAlarmScheduler();
        for (final sound in AlarmSound.values) {
          final details = scheduler.detailsForTesting(
            ScheduledAlarm(
              id: 1,
              at: DateTime(2026, 1, 1, 8),
              title: 'Routine',
              body: 'Next step',
              sound: sound,
            ),
          );
          expect(details.android, isNotNull);
          expect(details.android!.playSound, isTrue);
          expect(details.android!.enableVibration, isTrue);
          // Gene - Nov, 22, 2026: Require createIfNotExists so Android 8+ creates channels cleanly on first use, plus public lockscreen visibility and auto-cancelling Snooze action.
          expect(
            details.android!.channelAction,
            AndroidNotificationChannelAction.createIfNotExists,
          );
          expect(
            details.android!.visibility,
            NotificationVisibility.public,
          );
          final snoozeAction = details.android!.actions!.firstWhere(
            (a) => a.id == LocalNotificationAlarmScheduler.snooze5mActionId,
          );
          expect(snoozeAction.cancelNotification, isTrue);
          expect(
            details.android!.sound,
            isA<RawResourceAndroidNotificationSound>(),
          );
          expect(details.iOS, isNotNull);
          expect(details.iOS!.presentSound, isTrue);
          expect(details.iOS!.presentBanner, isTrue);
          expect(details.iOS!.presentAlert, isTrue);
          expect(details.iOS!.presentList, isTrue);
          expect(details.iOS!.sound, sound.fileName);
        }

        final completionDetails = scheduler.detailsForTesting(
          ScheduledAlarm(
            id: 2,
            at: DateTime(2026, 1, 1, 8, 1),
            title: 'Routine',
            body: 'Routine complete.',
            sound: AlarmSound.chime,
            isCompletion: true,
          ),
        );
        expect(completionDetails.android!.playSound, isTrue);
        expect(
          completionDetails.iOS!.sound,
          AudioCuePlayer.completionSound,
        );
      },
    );

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

  // Gene - Nov, 15, 2026: Regression tests covering Android manifest receivers, cross-instance scheduler serialization, 20-alarm OS cap + replenishment, Android exact-alarm fallback, sub-second trigger normalization, and multi-lap Activity background alarms.
  group('background notification delivery hardening', () {
    test(
      'AndroidManifest and iOS AppDelegate declare required background notification handlers',
      () {
        final manifest =
            File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
        expect(
          manifest,
          contains('android.permission.USE_FULL_SCREEN_INTENT'),
        );
        expect(
          manifest,
          contains(
            'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
          ),
        );
        expect(
          manifest,
          contains(
            'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
          ),
        );
        expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
        expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
        expect(
          manifest,
          contains(
            'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver',
          ),
        );

        final appDelegate =
            File('ios/Runner/AppDelegate.swift').readAsStringSync();
        expect(
          appDelegate,
          contains('FlutterLocalNotificationsPlugin.setPluginRegistrantCallback'),
        );
      },
    );

    test(
      'cross-instance cancelAll and schedule serialize cleanly for Activity, Interval, and Brew',
      () async {
        final now = DateTime(2026, 1, 1, 8, 0, 0);
        for (final idBase in [
          LocalNotificationAlarmScheduler.activityIdBase,
          LocalNotificationAlarmScheduler.brewIdBase,
          LocalNotificationAlarmScheduler.intervalIdBase,
        ]) {
          final plugin = _MockSchedulingNotificationsPlugin(
            cancelDelay: const Duration(milliseconds: 25),
          );
          final oldScheduler = LocalNotificationAlarmScheduler(
            plugin: plugin,
            idBase: idBase,
            clock: () => now,
          );
          final newScheduler = LocalNotificationAlarmScheduler(
            plugin: plugin,
            idBase: idBase,
            clock: () => now,
          );

          await oldScheduler.schedule([
            ScheduledAlarm(
              id: 0,
              at: now.add(const Duration(seconds: 30)),
              title: 'Old',
              body: 'Step 1',
            ),
          ]);
          expect(plugin.activePending.keys, [idBase + 0]);

          // Simulate oldController.onClose() racing immediately against
          // newController.onInit() for the same session block.
          await Future.wait([
            oldScheduler.cancelAll(),
            newScheduler.schedule([
              ScheduledAlarm(
                id: 0,
                at: now.add(const Duration(seconds: 60)),
                title: 'New',
                body: 'Step 1',
              ),
            ]),
          ]);

          expect(
            plugin.activePending.keys,
            [idBase + 0],
            reason:
                'New session alarms for idBase=$idBase must survive old cancelAll()',
          );
          expect(plugin.activePending[idBase + 0]?.title, 'New');
        }
      },
    );

    test(
      'LocalNotificationAlarmScheduler caps queued OS alarms to maxPendingPerSession (20)',
      () async {
        final now = DateTime(2026, 1, 1, 8, 0, 0);
        final plugin = _MockSchedulingNotificationsPlugin();
        final scheduler = LocalNotificationAlarmScheduler(
          plugin: plugin,
          idBase: LocalNotificationAlarmScheduler.intervalIdBase,
          clock: () => now,
        );

        final alarms = List.generate(
          50,
          (i) => ScheduledAlarm(
            id: i,
            at: now.add(Duration(minutes: i + 1)),
            title: 'Long Interval',
            body: 'Alarm ${i + 1} of 50',
          ),
        );

        await scheduler.schedule(alarms);

        expect(
          plugin.activePending.length,
          LocalNotificationAlarmScheduler.maxPendingPerSession,
        );
        final firstId = LocalNotificationAlarmScheduler.intervalIdBase;
        expect(plugin.activePending.containsKey(firstId), isTrue);
        expect(plugin.activePending.containsKey(firstId + 19), isTrue);
        expect(plugin.activePending.containsKey(firstId + 20), isFalse);
      },
    );

    testWidgets(
      'IntervalRunController replenishes its 20-alarm rolling window on tick and wraps IDs past 1000',
      (tester) async {
        final clock = _Clock(DateTime(2026, 1, 1, 8, 0, 30));
        final scheduler = _RecordingScheduler();
        final timer = IntervalTimer(
          name: 'Rolling Stretch',
          startTime: DateTime(2026, 1, 1, 8, 0),
          endTime: DateTime(2026, 1, 1, 8, 30),
          intervalValue: 1,
          intervalType: IntervalType.minute,
        );
        final controller = IntervalRunController(
          timer: timer,
          cuePlayer: _SilentCuePlayer(),
          scheduler: scheduler,
          clock: () => clock.now,
          historyLogger: (_) async {},
          tickInterval: const Duration(milliseconds: 100),
        )..onInit();

        await tester.pump(const Duration(milliseconds: 10));
        expect(
          scheduler.latest,
          hasLength(LocalNotificationAlarmScheduler.maxPendingPerSession),
        );
        expect(scheduler.latest.first.at, DateTime(2026, 1, 1, 8, 1));
        expect(scheduler.latest.last.at, DateTime(2026, 1, 1, 8, 20));

        // Advance past 5 alarms in the foreground; controller must replenish
        // the rolling 20-alarm window up to 08:25.
        clock.now = DateTime(2026, 1, 1, 8, 5, 10);
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          scheduler.latest,
          hasLength(LocalNotificationAlarmScheduler.maxPendingPerSession),
        );
        expect(scheduler.latest.first.at, DateTime(2026, 1, 1, 8, 6));
        expect(scheduler.latest.last.at, DateTime(2026, 1, 1, 8, 25));

        controller.onClose();

        // Also verify schedules with >1000 total alarms wrap IDs within idSpaceSize.
        final marathonClock = _Clock(DateTime(2026, 1, 1, 17, 10));
        final marathonController = IntervalRunController(
          timer: IntervalTimer(
            name: 'All Day',
            startTime: DateTime(2026, 1, 1, 0, 0),
            endTime: DateTime(2026, 1, 1, 20, 0),
            intervalValue: 1,
            intervalType: IntervalType.minute,
          ),
          cuePlayer: _SilentCuePlayer(),
          scheduler: _RecordingScheduler(),
          clock: () => marathonClock.now,
          historyLogger: (_) async {},
        )..onInit();

        final marathonAlarms = marathonController.pendingAlarms();
        expect(
          marathonAlarms,
          hasLength(LocalNotificationAlarmScheduler.maxPendingPerSession),
        );
        for (final alarm in marathonAlarms) {
          expect(alarm.id, inInclusiveRange(0, LocalNotificationAlarmScheduler.idSpaceSize - 1));
        }

        marathonController.onClose();
      },
    );

    testWidgets(
      'BrewRunController re-syncs background alarms when advancing to the next pour step',
      (tester) async {
        final scheduler = _RecordingScheduler();
        final clock = _Clock(DateTime(2026, 1, 1, 8, 0, 0));
        final controller = BrewRunController(
          recipe: BrewRecipe(
            name: 'Multi-step Brew',
            method: BrewMethod.v60,
            doseGrams: 20,
            ratio: 16,
            steps: [
              BrewStep(
                name: 'Bloom',
                seconds: 30,
                pourToFraction: 0.2,
                pourSeconds: 10,
              ),
              BrewStep(
                name: 'Pour 1',
                seconds: 40,
                pourToFraction: 0.6,
                pourSeconds: 15,
              ),
              BrewStep(
                name: 'Pour 2',
                seconds: 50,
                pourToFraction: 1.0,
                pourSeconds: 20,
              ),
            ],
          ),
          cuePlayer: _SilentCuePlayer(),
          scheduler: scheduler,
          clock: () => clock.now,
          tickInterval: const Duration(milliseconds: 100),
        )..start();

        await tester.pump(const Duration(milliseconds: 10));
        expect(scheduler.scheduled, hasLength(1));

        clock.now = DateTime(2026, 1, 1, 8, 0, 31);
        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.stepIndex.value, 1);
        expect(scheduler.scheduled.length, greaterThanOrEqualTo(2));
        expect(scheduler.latest.map((a) => a.at), [
          DateTime(2026, 1, 1, 8, 1, 10),
          DateTime(2026, 1, 1, 8, 2, 0),
        ]);

        controller.onClose();
      },
    );

    test(
      'Android scheduling falls back to inexactAllowWhileIdle when exact alarms are denied or throw PlatformException',
      () async {
        final now = DateTime(2026, 1, 1, 8, 0, 0);

        // 1. Device explicitly reports exact alarms not permitted.
        final deniedPlugin = _MockSchedulingNotificationsPlugin(
          androidPlugin: _MockAndroidNotificationsPlugin(canScheduleExact: false),
        );
        final deniedScheduler = LocalNotificationAlarmScheduler(
          plugin: deniedPlugin,
          idBase: LocalNotificationAlarmScheduler.brewIdBase,
          clock: () => now,
        );
        await deniedScheduler.schedule([
          ScheduledAlarm(
            id: 0,
            at: now.add(const Duration(seconds: 20)),
            title: 'V60',
            body: 'Bloom done',
          ),
        ]);
        expect(deniedPlugin.scheduleCalls, hasLength(1));
        expect(
          deniedPlugin.scheduleCalls.single.androidScheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle,
        );

        // 2. Device throws PlatformException on exactAllowWhileIdle and retries inexact.
        final throwingPlugin = _MockSchedulingNotificationsPlugin(
          androidPlugin: _MockAndroidNotificationsPlugin(canScheduleExact: true),
          throwExactAlarmExceptionOnce: true,
        );
        final throwingScheduler = LocalNotificationAlarmScheduler(
          plugin: throwingPlugin,
          idBase: LocalNotificationAlarmScheduler.activityIdBase,
          clock: () => now,
        );
        await throwingScheduler.schedule([
          ScheduledAlarm(
            id: 1,
            at: now.add(const Duration(seconds: 20)),
            title: 'Routine',
            body: 'Next: Plank',
          ),
          ScheduledAlarm(
            id: 2,
            at: now.add(const Duration(seconds: 50)),
            title: 'Routine',
            body: 'Routine complete.',
            isCompletion: true,
          ),
        ]);
        expect(throwingPlugin.scheduleCalls, hasLength(2));
        expect(
          throwingPlugin.scheduleCalls.every(
            (r) => r.androidScheduleMode == AndroidScheduleMode.inexactAllowWhileIdle,
          ),
          isTrue,
        );
        expect(throwingPlugin.activePending, hasLength(2));
      },
    );

    test(
      'sub-second trigger times round up to whole seconds while exact seconds stay unchanged',
      () async {
        final now = DateTime(2026, 1, 1, 8, 0, 0, 200);
        final plugin = _MockSchedulingNotificationsPlugin();
        final scheduler = LocalNotificationAlarmScheduler(
          plugin: plugin,
          idBase: LocalNotificationAlarmScheduler.activityIdBase,
          clock: () => now,
        );

        await scheduler.schedule([
          ScheduledAlarm(
            id: 1,
            at: DateTime(2026, 1, 1, 8, 0, 0, 700), // +500ms within current second
            title: 'Routine',
            body: 'Near step',
          ),
          ScheduledAlarm(
            id: 2,
            at: DateTime(2026, 1, 1, 8, 0, 10, 400),
            title: 'Routine',
            body: 'Sub-second step',
          ),
          ScheduledAlarm(
            id: 3,
            at: DateTime(2026, 1, 1, 8, 1, 0),
            title: 'Routine',
            body: 'Whole-second step',
          ),
        ]);

        expect(plugin.scheduleCalls, hasLength(3));
        expect(
          plugin.scheduleCalls[0].scheduledDate,
          tz.TZDateTime.from(DateTime(2026, 1, 1, 8, 0, 1), tz.local),
        );
        expect(
          plugin.scheduleCalls[1].scheduledDate,
          tz.TZDateTime.from(DateTime(2026, 1, 1, 8, 0, 11), tz.local),
        );
        expect(
          plugin.scheduleCalls[2].scheduledDate,
          tz.TZDateTime.from(DateTime(2026, 1, 1, 8, 1, 0), tz.local),
        );
      },
    );

    test(
      'looping ActivityRunController pre-schedules multiple laps up to maxPendingPerSession',
      () {
        final clock = _Clock(DateTime(2026, 1, 1, 8, 0, 0));
        final sequence = TimerSequence(
          id: 'loop-routine',
          name: 'HIIT Loop',
          defaultLoopEnabled: true,
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Sprint',
              durationInSeconds: 30,
              phase: IntervalPhase.work,
            ),
            ActivityTimer(
              name: 'Recover',
              durationInSeconds: 15,
              phase: IntervalPhase.rest,
            ),
          ],
        );
        final controller = ActivityRunController(
          sequence: sequence,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _RecordingScheduler(),
          clock: () => clock.now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        )..onInit();
        controller.start();

        final alarms = controller.pendingAlarms();
        expect(
          alarms,
          hasLength(LocalNotificationAlarmScheduler.maxPendingPerSession),
        );
        // Lap boundary step announces restart with the first step name and isCompletion == false.
        expect(alarms[1].body, 'Next: Sprint');
        expect(alarms[1].isCompletion, isFalse);
        // Alarms advance chronologically through lap 2 (and beyond).
        expect(alarms[2].at, DateTime(2026, 1, 1, 8, 1, 15));
        expect(alarms[3].at, DateTime(2026, 1, 1, 8, 1, 30));
        expect(alarms.map((a) => a.id).toSet(), hasLength(alarms.length));
        for (final alarm in alarms) {
          expect(
            alarm.id,
            inInclusiveRange(1, LocalNotificationAlarmScheduler.idSpaceSize - 1),
          );
        }

        controller.onClose();
      },
    );
  });
}

class _ScheduledRecord {
  _ScheduledRecord({
    required this.id,
    required this.scheduledDate,
    required this.androidScheduleMode,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final tz.TZDateTime scheduledDate;
  final AndroidScheduleMode androidScheduleMode;
  final String? title;
  final String? body;
  final String? payload;
}

class _MockAndroidNotificationsPlugin extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  _MockAndroidNotificationsPlugin({this.canScheduleExact = true});

  final bool canScheduleExact;

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {}

  @override
  Future<void> deleteNotificationChannel({required String channelId}) async {}

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<bool?> canScheduleExactNotifications() async => canScheduleExact;

  @override
  Future<bool?> requestNotificationsPermission() async => true;
}

class _MockSchedulingNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  _MockSchedulingNotificationsPlugin({
    this.androidPlugin,
    this.throwExactAlarmExceptionOnce = false,
    this.cancelDelay = Duration.zero,
  });

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin;
  final bool throwExactAlarmExceptionOnce;
  final Duration cancelDelay;

  bool _threwExactException = false;
  final List<_ScheduledRecord> scheduleCalls = <_ScheduledRecord>[];
  final Map<int, _ScheduledRecord> activePending = <int, _ScheduledRecord>{};

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return androidPlugin as T?;
    }
    return null;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (throwExactAlarmExceptionOnce &&
        androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle &&
        !_threwExactException) {
      _threwExactException = true;
      throw PlatformException(
        code: 'exact_alarms_not_permitted',
        message: 'Exact alarms are not permitted',
      );
    }
    final record = _ScheduledRecord(
      id: id,
      scheduledDate: scheduledDate,
      androidScheduleMode: androidScheduleMode,
      title: title,
      body: body,
      payload: payload,
    );
    scheduleCalls.add(record);
    activePending[id] = record;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return activePending.values
        .map(
          (r) => PendingNotificationRequest(r.id, r.title, r.body, r.payload),
        )
        .toList();
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (cancelDelay > Duration.zero) {
      await Future<void>.delayed(cancelDelay);
    }
    activePending.remove(id);
  }
}
