// Gene - Nov, 22, 2026: Comprehensive iOS & Android notification, audio cue, session lifecycle, wakelock, and UI QA regression test suite.
import 'dart:io';

import 'package:activity_timer/controllers/activity_list_controller.dart';
import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/controllers/brew_controller.dart';
import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/controllers/interval_timer_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/screens/edit_interval_timer_screen.dart';
import 'package:activity_timer/screens/interval_timer_screen.dart';
import 'package:activity_timer/screens/settings_screen.dart';
import 'package:activity_timer/screens/timer_screen.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/brew_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:activity_timer/services/wakelock_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timezone/timezone.dart' as tz;

class _SilentCuePlayer implements CuePlayer, PromptCuePlayer {
  @override
  Future<void> playAlarm(AlarmSound sound) async {}

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> playCountdownTick() async {}

  @override
  Future<void> playHalfwayWarning() async {}

  @override
  Future<void> dispose() async {}
}

class _CountingScheduler implements AlarmScheduler {
  int scheduleCalls = 0;
  int cancelCalls = 0;
  List<ScheduledAlarm> lastScheduled = const [];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {
    scheduleCalls++;
    lastScheduled = List.from(alarms);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
  }
}

class _SpyAndroidNotificationsPlugin extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  _SpyAndroidNotificationsPlugin({
    this.notificationsEnabled = true,
    this.canScheduleExact = true,
  });

  bool? notificationsEnabled;
  bool? canScheduleExact;
  final List<AndroidNotificationChannel> createdChannels = [];
  final List<String> deletedChannels = [];
  int permissionRequests = 0;

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {
    createdChannels.add(notificationChannel);
  }

  @override
  Future<void> deleteNotificationChannel({required String channelId}) async {
    deletedChannels.add(channelId);
  }

  @override
  Future<bool?> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<bool?> canScheduleExactNotifications() async => canScheduleExact;

  @override
  Future<bool?> requestNotificationsPermission() async {
    permissionRequests++;
    return true;
  }
}

class _SpyNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  _SpyNotificationsPlugin({this.androidPlugin, this.launchDetails});

  final _SpyAndroidNotificationsPlugin? androidPlugin;
  final NotificationAppLaunchDetails? launchDetails;

  InitializationSettings? lastInitSettings;
  final List<int> cancelledIds = [];
  final Map<int, ({String? title, tz.TZDateTime date, NotificationDetails details})>
  activePending = {};
  int zonedScheduleCalls = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    lastInitSettings = settings;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async =>
      launchDetails;

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
    zonedScheduleCalls++;
    activePending[id] = (
      title: title,
      date: scheduledDate,
      details: notificationDetails,
    );
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      activePending.entries
          .map(
            (e) => PendingNotificationRequest(e.key, e.value.title, null, null),
          )
          .toList();

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
    activePending.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseService db;
  var wakelockToggleCalls = 0;
  var openedNotificationSettings = 0;

  setUpAll(() async {
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.genexis.activitytimer/platform'),
          (call) async {
            if (call.method == 'getLocalTimezone') {
              return 'UTC';
            }
            if (call.method == 'openNotificationSettings') {
              openedNotificationSettings++;
              return true;
            }
            return null;
          },
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async {
            wakelockToggleCalls++;
            return const StandardMessageCodec().encodeMessage(<Object?>[null]);
          },
        );

    tempDir = await Directory.systemTemp.createTemp(
      'notification_qa_regression_test',
    );
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    db = DatabaseService();
    await db.init();
    await AppSettings().loadSettings();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    wakelockToggleCalls = 0;
    openedNotificationSettings = 0;
    await AppSettings().setSoundEnabled(true);
    await AppSettings().setVibrationEnabled(true);
    LocalNotificationAlarmScheduler.resetForTesting();
    setUpLocator();
  });

  tearDown(() async {
    ActivitySessionService().clear();
    IntervalSessionService().clear();
    BrewSessionService().clear();
    await AppSettings().setSoundEnabled(true);
    await AppSettings().setVibrationEnabled(true);
    LocalNotificationAlarmScheduler.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    await resetLocator();
  });

  group('Android & iOS Notification Channel, Icon, Sound & Foregroundfixes', () {
    test(
      'Android _init uses ic_stat_timer, cleans v1/v2 channels, and proactively creates v3 sound/vibrate/silent channels',
      () async {
        final androidSpy = _SpyAndroidNotificationsPlugin();
        final plugin = _SpyNotificationsPlugin(androidPlugin: androidSpy);
        final scheduler = LocalNotificationAlarmScheduler(plugin: plugin);

        await scheduler.schedule([
          ScheduledAlarm(
            id: 1,
            at: DateTime.now().add(const Duration(minutes: 1)),
            title: 'Test',
            body: 'Body',
            sound: AlarmSound.bell,
          ),
        ]);

        expect(plugin.lastInitSettings?.android?.defaultIcon, 'ic_stat_timer');
        expect(
          androidSpy.deletedChannels,
          containsAll([
            LocalNotificationAlarmScheduler.channelId,
            LocalNotificationAlarmScheduler.channelIdV2,
            '${LocalNotificationAlarmScheduler.channelId}_bell',
            '${LocalNotificationAlarmScheduler.channelIdV2}_bell',
          ]),
        );

        final createdIds = androidSpy.createdChannels.map((c) => c.id).toSet();
        expect(
          createdIds,
          containsAll([
            LocalNotificationAlarmScheduler.channelIdFor(
              AlarmSound.bell,
              isCompletion: false,
            ),
            LocalNotificationAlarmScheduler.channelIdFor(
              null,
              isCompletion: true,
            ),
            LocalNotificationAlarmScheduler.channelIdFor(
              AlarmSound.bell,
              isCompletion: false,
              playSound: false,
              enableVibration: true,
            ),
            LocalNotificationAlarmScheduler.channelIdFor(
              AlarmSound.bell,
              isCompletion: false,
              playSound: false,
              enableVibration: false,
            ),
          ]),
        );
      },
    );

    test(
      '_detailsFor respects AppSettings().soundEnabled and vibrationEnabled on Android & iOS',
      () async {
        final scheduler = LocalNotificationAlarmScheduler();
        final alarm = ScheduledAlarm(
          id: 1,
          at: DateTime(2026, 11, 22, 9),
          title: 'HIIT',
          body: 'Next',
          sound: AlarmSound.chime,
        );

        await AppSettings().setSoundEnabled(false);
        await AppSettings().setVibrationEnabled(true);
        var details = scheduler.detailsForTesting(alarm);
        expect(details.android!.playSound, isFalse);
        expect(details.android!.enableVibration, isTrue);
        expect(details.android!.sound, isNull);
        expect(details.android!.silent, isFalse);
        expect(details.iOS!.presentSound, isFalse);
        expect(details.iOS!.sound, isNull);

        await AppSettings().setVibrationEnabled(false);
        details = scheduler.detailsForTesting(alarm);
        expect(details.android!.playSound, isFalse);
        expect(details.android!.enableVibration, isFalse);
        expect(details.android!.silent, isTrue);
        expect(
          details.android!.channelId,
          '${LocalNotificationAlarmScheduler.channelIdV3}_silent',
        );
      },
    );

    test(
      'Android foreground deferral suppresses zonedSchedule in foreground and flushes on background',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final now = DateTime(2026, 11, 22, 9, 0, 0);
        final plugin = _SpyNotificationsPlugin();
        final scheduler = LocalNotificationAlarmScheduler(
          plugin: plugin,
          idBase: LocalNotificationAlarmScheduler.activityIdBase,
          clock: () => now,
        );

        LocalNotificationAlarmScheduler.setAppInForeground(
          true,
          plugin: plugin,
        );
        await scheduler.schedule([
          ScheduledAlarm(
            id: 1,
            at: now.add(const Duration(seconds: 30)),
            title: 'Sprint',
            body: 'Rest',
          ),
        ]);
        expect(plugin.zonedScheduleCalls, 0);
        expect(plugin.activePending, isEmpty);

        // Switching to background flushes the cached alarms immediately.
        await LocalNotificationAlarmScheduler.onAppBackgrounded(plugin: plugin);
        expect(plugin.zonedScheduleCalls, 1);
        expect(
          plugin.activePending.keys,
          [LocalNotificationAlarmScheduler.activityIdBase + 1],
        );

        // Returning to foreground withdraws unfired OS alarms.
        await LocalNotificationAlarmScheduler.onAppForegrounded(plugin: plugin);
        expect(plugin.activePending, isEmpty);
      },
    );

    test(
      'ensurePermission deduplicates concurrent requests and skips re-prompting once granted',
      () async {
        final androidSpy = _SpyAndroidNotificationsPlugin(
          notificationsEnabled: false,
        );
        final plugin = _SpyNotificationsPlugin(androidPlugin: androidSpy);
        final scheduler = LocalNotificationAlarmScheduler(plugin: plugin);

        final results = await Future.wait([
          scheduler.ensurePermission(),
          scheduler.ensurePermission(),
          scheduler.ensurePermission(),
        ]);
        expect(results, [true, true, true]);
        expect(androidSpy.permissionRequests, 1);

        // Already granted in state/OS: no second OS prompt.
        androidSpy.notificationsEnabled = true;
        final again = await scheduler.ensurePermission();
        expect(again, isTrue);
        expect(androidSpy.permissionRequests, 1);

        // checkNotificationStatus inspects both notification and exact alarm states.
        final blockedExact = _SpyAndroidNotificationsPlugin(
          notificationsEnabled: true,
          canScheduleExact: false,
        );
        final status =
            await LocalNotificationAlarmScheduler.checkNotificationStatus(
              plugin: _SpyNotificationsPlugin(androidPlugin: blockedExact),
            );
        expect(status.notificationsEnabled, isTrue);
        expect(status.exactAlarmsEnabled, isFalse);
        expect(status.needsAttention, isTrue);
      },
    );
  });

  group('Cold-Start & Background Notification Actions (Snooze 5m & Dismiss)', () {
    test(
      'cold-start snooze_5m re-arms a completed Activity routine BEFORE restoreSessionIfActive cleans it up',
      () async {
        final seq = TimerSequence(
          id: 'cold-snooze-act',
          name: 'Quick Mobility',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Stretch',
              durationInSeconds: 30,
              phase: IntervalPhase.work,
            ),
          ],
        );
        await db.createActivitySequence(seq);

        final spyPlugin = _SpyNotificationsPlugin(
          launchDetails: const NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotificationAction,
              id: 9001,
              actionId: LocalNotificationAlarmScheduler.snooze5mActionId,
              payload: 'activity:cold-snooze-act',
            ),
          ),
        );

        final handled =
            await LocalNotificationAlarmScheduler.handleLaunchDetailsBeforeRestore(
              await spyPlugin.getNotificationAppLaunchDetails(),
              plugin: spyPlugin,
            );
        expect(handled, isTrue);
        expect(spyPlugin.cancelledIds, contains(9001));
        expect(ActivitySessionService().active.value, isNotNull);
        expect(
          ActivitySessionService().active.value!.isRunning.value,
          isTrue,
        );
        expect(
          ActivitySessionService().active.value!.remainingMs.value,
          closeTo(const Duration(minutes: 5).inMilliseconds, 2000),
        );

        // Subsequent restoreSessionIfActive keeps the newly snoozed routine alive.
        final restored =
            await ActivitySessionService().restoreSessionIfActive();
        expect(restored, isNotNull);

        await db.deleteActivitySequence(seq.id);
      },
    );

    test(
      'warm-start snooze_5m still recovers a just-completed routine cleared by syncOrRestore',
      () async {
        var now = DateTime(2026, 11, 22, 10, 0, 0);
        final seq = TimerSequence(
          id: 'warm-snooze-act',
          name: 'Warm Snooze',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Focus',
              durationInSeconds: 20,
              phase: IntervalPhase.work,
            ),
          ],
        );
        final ctrl = ActivitySessionService().obtain(
          seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
        );
        expect(ctrl.isRunning.value, isTrue);

        // Advance past completion when resumed -> syncOrRestore clears active but preserves snooze fallback.
        now = now.add(const Duration(seconds: 25));
        final synced = await ActivitySessionService().syncOrRestore(
          clock: () => now,
        );
        expect(synced, isNull);
        expect(ActivitySessionService().active.value, isNull);

        await LocalNotificationAlarmScheduler.handlePayload(
          'activity:warm-snooze-act',
          actionId: LocalNotificationAlarmScheduler.snooze5mActionId,
          notificationId: 9001,
        );
        expect(ActivitySessionService().active.value, isNotNull);
        expect(
          ActivitySessionService().active.value!.isRunning.value,
          isTrue,
        );
      },
    );

    test(
      'cold-start dismiss_alarm clears DB session and disarms IntervalTimer.isActive even when active.value is null',
      () async {
        final now = DateTime(2026, 11, 22, 10, 0, 0);
        final timer = IntervalTimer(
          id: 'cold-dismiss-int',
          name: 'Medicine Alert',
          startTime: now.subtract(const Duration(minutes: 1)),
          endTime: now.add(const Duration(hours: 1)),
          intervalValue: 30,
          intervalType: IntervalType.minute,
          isPointInTime: true,
          isActive: true,
        );
        await db.createIntervalTimer(timer);
        await locator<IntervalTimerController>().loadIntervalTimers();
        await db.saveActiveIntervalSession({
          'timerId': timer.id,
          'startedAtMs': now.millisecondsSinceEpoch,
        });
        expect(await db.getActiveIntervalSession(), isNotNull);

        await LocalNotificationAlarmScheduler.handlePayload(
          'interval:cold-dismiss-int',
          actionId: LocalNotificationAlarmScheduler.dismissActionId,
          notificationId: 11000,
        );
        await Future<void>.delayed(Duration.zero);

        expect(await db.getActiveIntervalSession(), isNull);
        final updated = await db.getIntervalTimer(timer.id);
        expect(updated?.isActive, isFalse);

        await db.deleteIntervalTimer(timer.id);
      },
    );
  });

  group('Session Snapshot Restoration, Run Controllers, Deletion & Wakelock', () {
    test(
      'IntervalSessionService snapshot preserves paused/snoozed state and does not roll completed alerts over to tomorrow',
      () async {
        var now = DateTime(2026, 11, 22, 8, 0, 0);
        final scheduler = _CountingScheduler();
        final timer = IntervalTimer(
          id: 'snap-int-1',
          name: 'Hydration',
          startTime: DateTime(2026, 11, 22, 9, 0),
          endTime: DateTime(2026, 11, 22, 9, 30),
          intervalValue: 30,
          intervalType: IntervalType.minute,
          isActive: true,
        );
        await db.createIntervalTimer(timer);

        // 1. Start and pause -> evict memory -> restore must remain PAUSED.
        final started = IntervalSessionService().obtain(
          timer,
          cuePlayer: _SilentCuePlayer(),
          scheduler: scheduler,
          clock: () => now,
        );
        started.toggle(); // paused
        await Future<void>.delayed(Duration.zero);
        IntervalSessionService().suspendInMemory();

        final restoredPaused = await IntervalSessionService()
            .restoreSessionIfActive(
              databaseService: db,
              cuePlayer: _SilentCuePlayer(),
              scheduler: scheduler,
              clock: () => now,
            );
        expect(restoredPaused, isNotNull);
        expect(restoredPaused!.isRunning.value, isFalse);

        // 2. Resume, snooze +5m, evict memory -> restore keeps snooze target.
        restoredPaused.toggle(); // running
        restoredPaused.snooze(const Duration(minutes: 5));
        await Future<void>.delayed(Duration.zero);
        IntervalSessionService().suspendInMemory();

        now = now.add(const Duration(minutes: 2));
        final restoredSnoozed = await IntervalSessionService()
            .restoreSessionIfActive(
              databaseService: db,
              cuePlayer: _SilentCuePlayer(),
              scheduler: scheduler,
              clock: () => now,
            );
        expect(restoredSnoozed, isNotNull);
        expect(restoredSnoozed!.isRunning.value, isTrue);
        expect(
          restoredSnoozed.untilNextAlarm,
          const Duration(minutes: 3),
        );

        // 3. Advance past the entire saved window while evicted -> must complete, NOT shift to tomorrow!
        now = DateTime(2026, 11, 22, 10, 0, 0);
        IntervalSessionService().suspendInMemory();
        final afterEnd = await IntervalSessionService().restoreSessionIfActive(
          databaseService: db,
          cuePlayer: _SilentCuePlayer(),
          scheduler: scheduler,
          clock: () => now,
        );
        expect(afterEnd, isNull);
        expect((await db.getIntervalTimer(timer.id))?.isActive, isFalse);

        await db.deleteIntervalTimer(timer.id);
      },
    );

    test(
      'ActivityRunController keeps paused state on skipToNext (prep & step), persists toggleLoop, and restores expanded durations',
      () async {
        final now = DateTime(2026, 11, 22, 11, 0, 0);
        Map<String, dynamic>? savedSnapshot;
        final seq = TimerSequence(
          id: 'act-paused-nav',
          name: 'Stretch',
          preparationSeconds: 5,
          timers: [
            ActivityTimer(
              name: 'Step 1',
              durationInSeconds: 20,
              phase: IntervalPhase.work,
            ),
            ActivityTimer(
              name: 'Step 2',
              durationInSeconds: 30,
              phase: IntervalPhase.rest,
            ),
          ],
        );
        final ctrl = ActivityRunController(
          sequence: seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (data) async => savedSnapshot = data,
          sessionClearer: () async {},
        )..onInit();

        // Pause during prep and skip prep -> stays paused on Step 1 with null deadline.
        ctrl.pause();
        ctrl.skipToNext();
        await Future<void>.delayed(Duration.zero);
        expect(ctrl.isPreparing.value, isFalse);
        expect(ctrl.isRunning.value, isFalse);
        expect(ctrl.currentIndex.value, 0);
        expect(savedSnapshot?['isRunning'], isFalse);
        expect(savedSnapshot?['deadlineMs'], isNull);

        // Extend paused step and toggle loop -> persists updated durations & loop flag.
        ctrl.addSeconds(30);
        ctrl.toggleLoop();
        await Future<void>.delayed(Duration.zero);
        expect(savedSnapshot?['loopEnabled'], isTrue);
        expect(savedSnapshot?['activeStepDurationMs'], 50000);

        ctrl.onClose();

        // Restoring past 50% initializes expanded duration and suppresses duplicate halfway cue.
        final restored = ActivityRunController(
          sequence: seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        );
        restored.restoreFromSnapshot(
          initialIndex: 0,
          wasPreparing: false,
          wasRunning: false,
          savedRemainingMs: 10000,
          deadlineMs: null,
          savedLoopEnabled: false,
          savedLoopCount: 0,
          savedActiveStepDurationMs: 50000,
          savedPrepDurationMs: 5000,
        );
        expect(restored.currentDurationMs, 50000);
        restored.onClose();
      },
    );

    test(
      'BrewRunController guards double start() and computes exact elapsed time on pause()',
      () {
        var now = DateTime(2026, 11, 22, 7, 0, 0);
        final ctrl = BrewRunController(
          recipe: BrewRecipe(
            name: 'V60',
            method: BrewMethod.v60,
            doseGrams: 15,
            ratio: 16,
            steps: [
              BrewStep(
                name: 'Bloom',
                seconds: 40,
                pourToFraction: 0.2,
                pourSeconds: 10,
              ),
            ],
          ),
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
        )..start();

        now = now.add(const Duration(seconds: 12));
        // Double start() must not wipe elapsed time since initial start.
        ctrl.start();
        ctrl.pause();

        expect(ctrl.isRunning.value, isFalse);
        expect(ctrl.elapsedInStepMs.value, 12000);
        ctrl.onClose();
      },
    );

    test(
      'deleting an active Activity, Interval, or Brew item clears its running session and OS alarms',
      () async {
        // Activity
        final seq = TimerSequence(
          id: 'del-act',
          name: 'Delete Me',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'One',
              durationInSeconds: 30,
              phase: IntervalPhase.work,
            ),
          ],
        );
        await db.createActivitySequence(seq);
        final actListCtrl = locator<ActivityListController>();
        await actListCtrl.loadSequences();
        ActivitySessionService().obtain(
          seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
        );
        final actIdx = actListCtrl.sequences.indexWhere((s) => s.id == seq.id);
        await actListCtrl.deleteSequence(actIdx);
        expect(ActivitySessionService().active.value, isNull);

        // Interval
        final timer = IntervalTimer(
          id: 'del-int',
          name: 'Delete Int',
          startTime: DateTime.now().add(const Duration(minutes: 5)),
          endTime: DateTime.now().add(const Duration(minutes: 60)),
          intervalValue: 15,
          intervalType: IntervalType.minute,
        );
        await db.createIntervalTimer(timer);
        final intListCtrl = locator<IntervalTimerController>();
        await intListCtrl.loadIntervalTimers();
        IntervalSessionService().obtain(
          timer,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
        );
        await intListCtrl.deleteIntervalTimer(timer.id);
        expect(IntervalSessionService().active.value, isNull);

        // Brew
        final recipe = BrewRecipe(
          id: 'del-brew',
          name: 'Delete Brew',
          method: BrewMethod.v60,
          doseGrams: 15,
          ratio: 16,
          steps: [
            BrewStep(
              name: 'Bloom',
              seconds: 30,
              pourToFraction: 1,
              pourSeconds: 10,
            ),
          ],
        );
        await db.createBrewRecipe(recipe);
        final brewListCtrl = locator<BrewController>();
        await brewListCtrl.loadRecipes();
        BrewSessionService().obtain(
          recipe,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
        );
        await brewListCtrl.deleteBrew(recipe.id);
        expect(BrewSessionService().active.value, isNull);
      },
    );

    test(
      'WakelockCoordinator keeps screen awake while another concurrent timer is still running',
      () async {
        final now = DateTime(2026, 11, 22, 12, 0, 0);
        final seq = TimerSequence(
          id: 'wl-act',
          name: 'Routine',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Step',
              durationInSeconds: 60,
              phase: IntervalPhase.work,
            ),
          ],
        );
        final brew = BrewRecipe(
          id: 'wl-brew',
          name: 'Brew',
          method: BrewMethod.v60,
          doseGrams: 15,
          ratio: 16,
          steps: [
            BrewStep(
              name: 'Pour',
              seconds: 60,
              pourToFraction: 1,
              pourSeconds: 10,
            ),
          ],
        );

        ActivitySessionService().obtain(
          seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
        );
        final brewCtrl = BrewSessionService().obtain(
          brew,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          clock: () => now,
        )..start();

        wakelockToggleCalls = 0;
        // Closing/pausing brew while activity is still running must NOT disable wakelock.
        brewCtrl.pause();
        await WakelockCoordinator.releaseIfIdle();
        expect(wakelockToggleCalls, 0);

        // Now stop activity -> all sessions idle -> releaseIfIdle disables wakelock once.
        ActivitySessionService().active.value!.pause();
        expect(wakelockToggleCalls, greaterThanOrEqualTo(1));
      },
    );
  });

  group('UI Fixes, Settings Permissions Row & Mute Sync', () {
    testWidgets(
      'TimerScreen completion view renders numeric loop count (not controller.toString())',
      (tester) async {
        final seq = TimerSequence(
          id: 'loop-ui-test',
          name: 'Loop Routine',
          preparationSeconds: 0,
          defaultLoopEnabled: true,
          timers: [
            ActivityTimer(
              name: 'Work',
              durationInSeconds: 10,
              phase: IntervalPhase.work,
            ),
          ],
        );
        final ctrl = ActivityRunController(
          sequence: seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _CountingScheduler(),
          historyLogger: (_) async {},
          sequenceSaver: (_) async {},
          sessionSaver: (_) async {},
          sessionClearer: () async {},
        );
        ctrl.loopCount.value = 2;
        ctrl.isCompleted.value = true;
        ctrl.isRunning.value = false;

        await tester.pumpWidget(
          MaterialApp(home: TimerScreen(sequence: seq, controller: ctrl)),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Loops completed: 2'), findsOneWidget);
        expect(
          find.textContaining("Instance of 'ActivityRunController'"),
          findsNothing,
        );

        ctrl.onClose();
      },
    );

    testWidgets(
      'TimerScreen & IntervalTimerScreen mute buttons sync AppController and reschedule active alarms',
      (tester) async {
        final scheduler = _CountingScheduler();
        final seq = TimerSequence(
          id: 'mute-act',
          name: 'Mute Test',
          preparationSeconds: 0,
          timers: [
            ActivityTimer(
              name: 'Focus',
              durationInSeconds: 60,
              phase: IntervalPhase.work,
            ),
          ],
        );
        final actCtrl = ActivitySessionService().obtain(
          seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: scheduler,
        );
        await tester.pump();
        final initialSchedules = scheduler.scheduleCalls;

        await tester.pumpWidget(
          MaterialApp(home: TimerScreen(sequence: seq, controller: actCtrl)),
        );
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.byTooltip('Mute sound'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(locator<AppController>().soundEnabled.value, isFalse);
        expect(AppSettings().soundEnabled, isFalse);
        expect(scheduler.scheduleCalls, greaterThan(initialSchedules));

        // Now verify IntervalTimerScreen un-mutes via AppController too.
        final timer = IntervalTimer(
          id: 'mute-int',
          name: 'Interval Mute',
          startTime: DateTime.now().add(const Duration(minutes: 1)),
          endTime: DateTime.now().add(const Duration(minutes: 60)),
          intervalValue: 15,
          intervalType: IntervalType.minute,
        );
        final intScheduler = _CountingScheduler();
        final intCtrl = IntervalSessionService().obtain(
          timer,
          cuePlayer: _SilentCuePlayer(),
          scheduler: intScheduler,
        );
        await tester.pump();
        final intInitial = intScheduler.scheduleCalls;

        await tester.pumpWidget(
          MaterialApp(
            home: IntervalTimerScreen(timer: timer, controller: intCtrl),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.byTooltip('Enable sound'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(locator<AppController>().soundEnabled.value, isTrue);
        expect(AppSettings().soundEnabled, isTrue);
        expect(intScheduler.scheduleCalls, greaterThan(intInitial));

        ActivitySessionService().clear();
        IntervalSessionService().clear();
        await tester.pump();
      },
    );

    testWidgets(
      'EditIntervalTimerScreen end-time picker anchors to _startTime calendar day after midnight wrap',
      (tester) async {
        final timer = IntervalTimer(
          id: 'edit-date-anchor',
          name: 'Evening Alert',
          startTime: DateTime(2026, 11, 22, 22, 0),
          // Midnight-wrapped next-day end time:
          endTime: DateTime(2026, 11, 23, 1, 0),
          intervalValue: 30,
          intervalType: IntervalType.minute,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EditIntervalTimerScreen(timer: timer, isNew: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Tap End Time selector button to open time picker.
        final endFinder = find.text('1:00 AM');
        expect(endFinder, findsOneWidget);
        await tester.tap(endFinder);
        await tester.pump(const Duration(milliseconds: 300));

        // Switch time picker to keyboard input mode and enter 11:00 PM scoped inside Dialog.
        final dialogFinder = find.byType(Dialog);
        final switchInput = find.descendant(
          of: dialogFinder,
          matching: find.byIcon(Icons.keyboard_outlined),
        );
        if (switchInput.evaluate().isNotEmpty) {
          await tester.tap(switchInput);
          await tester.pump(const Duration(milliseconds: 100));
          final pmChip = find.descendant(
            of: dialogFinder,
            matching: find.text('PM'),
          );
          if (pmChip.evaluate().isNotEmpty) {
            await tester.tap(pmChip.first);
            await tester.pump(const Duration(milliseconds: 50));
          }
          final fields = find.descendant(
            of: dialogFinder,
            matching: find.byType(TextFormField),
          );
          if (fields.evaluate().length >= 2) {
            await tester.enterText(
              fields.at(0),
              pmChip.evaluate().isNotEmpty ? '11' : '23',
            );
            await tester.enterText(fields.at(1), '00');
          }
        }
        await tester.tap(
          find.descendant(of: dialogFinder, matching: find.text('OK')),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('End time must be after start time. Adjusted automatically.'),
          findsNothing,
        );
        expect(find.text('11:00 PM'), findsWidgets);
        // 22:00 to 23:00 same day (every 30m) yields 3 alarms — never 51 across a stale +1 day wrap.
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
        expect(find.text('3 alarms will be triggered'), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen displays Notification Permissions tile with zero overflow on 320x568 @ 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final permTile = find.byKey(
          const Key('settings-notification-permissions'),
        );
        await tester.scrollUntilVisible(permTile, 200);
        expect(permTile, findsOneWidget);
        expect(find.text('Notification Permissions'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(permTile);
        await tester.pump(const Duration(milliseconds: 100));
        expect(openedNotificationSettings, greaterThanOrEqualTo(1));
      },
    );
  });
}
