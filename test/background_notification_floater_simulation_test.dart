// Gene - Nov, 7, 2026: End-to-end widget test simulations for hiding a running routine/alert/brew in the background, receiving a scheduled notification, clicking it, and opening the app with the running floating pill visible.

import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/brew_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

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

class _RecordingAlarmScheduler implements AlarmScheduler {
  final List<List<ScheduledAlarm>> scheduledBatches = [];
  int cancelCount = 0;

  List<ScheduledAlarm> get latestScheduled =>
      scheduledBatches.isEmpty ? const [] : scheduledBatches.last;

  /// Returns all alarms from the most recent schedule batch whose fire time
  /// has arrived at or before [now], simulating OS notifications appearing
  /// while the app is hidden in the background.
  List<ScheduledAlarm> appearedNotificationsAt(DateTime now) => [
    for (final alarm in latestScheduled)
      if (!alarm.at.isAfter(now)) alarm,
  ];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {
    scheduledBatches.add(List.from(alarms));
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }
}

/// Bounded frame pump helper since the running timer and navigation animations
/// repeat continuously.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseService db;
  late DateTime currentTime;

  setUpAll(() async {
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp(
      'background_notification_floater_simulation_test',
    );
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    db = DatabaseService();
    await db.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    currentTime = DateTime(2026, 11, 7, 9, 0, 0);
  });

  tearDown(() async {
    ActivitySessionService().clear();
    IntervalSessionService().clear();
    BrewSessionService().clear();
    await resetLocator();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    setUpLocator();
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: AppPages.createRouter()),
    );
    await settle(tester);
  }

  /// Simulates hiding the app in the background via Flutter's platform
  /// lifecycle transitions (`inactive` -> `hidden` -> `paused`).
  Future<void> hideAppInBackground(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  }

  /// Simulates the user tapping a delivered OS notification in the system tray
  /// and bringing the app back to the foreground (`hidden` -> `inactive` -> `resumed`).
  Future<void> tapNotificationAndOpenApp(
    WidgetTester tester,
    ScheduledAlarm notification,
  ) async {
    LocalNotificationAlarmScheduler.onNotificationTapped(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: notification.id,
        payload: notification.payload,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  }

  TimerSequence buildActivityRoutine() => TimerSequence(
    id: 'sim-activity-1',
    name: 'Morning Mobility',
    preparationSeconds: 0,
    timers: [
      ActivityTimer(
        name: 'Plank Hold',
        durationInSeconds: 30,
        phase: IntervalPhase.work,
      ),
      ActivityTimer(
        name: 'Cobra Stretch',
        durationInSeconds: 20,
        phase: IntervalPhase.rest,
      ),
    ],
  );

  testWidgets(
    'Activity run: hide app in background -> notification appears -> click notification -> opens app with running activity-floater showing caught-up step',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final routine = buildActivityRoutine();

      final session = ActivitySessionService();
      final controller = session.obtain(
        routine,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);

      // 1. Existing run is active and floating pill is showing Step 1.
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(
        find.text('Morning Mobility · Plank Hold'),
        findsOneWidget,
      );
      expect(find.text('0:30'), findsOneWidget);
      expect(controller.isRunning.value, isTrue);

      // 2. User hides the app in the background.
      await hideAppInBackground(tester);

      // 3. Time advances 35s in the background (5s past Step 1's 30s deadline),
      // so the scheduled Step 1 notification appears in the OS tray.
      currentTime = currentTime.add(const Duration(seconds: 35));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);
      final step1Notification = appeared.first;
      expect(step1Notification.title, equals('Morning Mobility'));
      expect(step1Notification.payload, equals('activity:${routine.id}'));

      // 4. User clicks the notification to open the app.
      await tapNotificationAndOpenApp(tester, step1Notification);

      // 5. App opens with the running floating pill visible and caught up to Step 2.
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(
        find.text('Morning Mobility · Cobra Stretch'),
        findsOneWidget,
      );
      expect(find.text('0:15'), findsOneWidget);
      expect(session.hasSessionInProgress, isTrue);

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Activity run on full TimerScreen: hide app in background -> notification appears -> click notification -> surfaces MainNavigation with running activity-floater showing',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final routine = buildActivityRoutine();

      final session = ActivitySessionService();
      session.obtain(
        routine,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);

      // Expand into the full-screen TimerScreen before backgrounding.
      await tester.tap(find.byKey(const Key('activity-floater')));
      await settle(tester);
      expect(find.text('remaining'), findsOneWidget);

      // Hide app in background while on the full TimerScreen.
      await hideAppInBackground(tester);

      // Advance clock 35s so the Step 1 notification appears.
      currentTime = currentTime.add(const Duration(seconds: 35));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);

      // Click the notification and resume the app.
      await tapNotificationAndOpenApp(tester, appeared.first);

      // Verify MainNavigation is surfaced and the running floating pill is visible.
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(
        find.text('Morning Mobility · Cobra Stretch'),
        findsOneWidget,
      );
      expect(find.text('0:15'), findsOneWidget);
      expect(session.hasSessionInProgress, isTrue);

      // Tapping the floating pill still expands the full TimerScreen on demand.
      await tester.tap(find.byKey(const Key('activity-floater')));
      await settle(tester);
      expect(find.text('remaining'), findsOneWidget);

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Activity run with background process eviction: hide app -> OS evicts memory -> notification appears -> click notification -> restores session and shows running activity-floater',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final routine = buildActivityRoutine();

      final session = ActivitySessionService();
      session.obtain(
        routine,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);

      // Hide app in background and simulate OS evicting the in-memory controller.
      await hideAppInBackground(tester);
      session.suspendInMemory();
      expect(session.active.value, isNull);

      // Notification fires 35s later while backgrounded.
      currentTime = currentTime.add(const Duration(seconds: 35));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);

      // User clicks the notification to reopen the app.
      await tapNotificationAndOpenApp(tester, appeared.first);

      // Session is restored from Hive and the running floating pill is showing!
      expect(session.active.value, isNotNull);
      expect(session.hasSessionInProgress, isTrue);
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(
        find.text('Morning Mobility · Cobra Stretch'),
        findsOneWidget,
      );
      expect(find.text('0:15'), findsOneWidget);

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Interval alert running: hide app in background -> alert notification appears -> click notification -> opens app with running interval-floater showing',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final alertTimer = IntervalTimer(
        id: 'sim-interval-1',
        name: 'Hydration Alert',
        startTime: currentTime.subtract(const Duration(minutes: 1)),
        endTime: currentTime.add(const Duration(minutes: 60)),
        intervalValue: 15,
        intervalType: IntervalType.minute,
      );

      final session = IntervalSessionService();
      session.obtain(
        alertTimer,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);

      // 1. Interval alert floater is visible on alarm 2 of 5 (at startTime + 15m = currentTime + 14m).
      expect(find.byKey(const Key('interval-floater')), findsOneWidget);
      expect(
        find.text('Hydration Alert · alarm 2 of 5'),
        findsOneWidget,
      );

      // 2. Hide app in background and simulate OS memory eviction.
      await hideAppInBackground(tester);
      session.suspendInMemory();
      expect(session.active.value, isNull);

      // 3. Advance clock by 16 minutes so alarm #2's notification appears.
      currentTime = currentTime.add(const Duration(minutes: 16));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);
      final alertNotification = appeared.first;
      expect(alertNotification.payload, equals('interval:${alertTimer.id}'));

      // 4. User clicks the alert notification to open the app.
      await tapNotificationAndOpenApp(tester, alertNotification);

      // 5. App opens with the running interval-floater visible and advanced to alarm 3 of 5!
      expect(session.hasSessionInProgress, isTrue);
      expect(find.byKey(const Key('interval-floater')), findsOneWidget);
      expect(
        find.text('Hydration Alert · alarm 3 of 5'),
        findsOneWidget,
      );

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Brew recipe running: hide app in background -> step notification appears -> click notification -> opens app with running brew-floater showing',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final brew = BrewRecipe(
        id: 'sim-brew-1',
        name: 'Morning V60',
        method: BrewMethod.v60,
        doseGrams: 20,
        ratio: 16,
        steps: [
          BrewStep(
            name: 'Bloom',
            seconds: 45,
            pourToFraction: 0.1875,
            pourSeconds: 15,
          ),
          BrewStep(
            name: 'Main pour',
            seconds: 120,
            pourToFraction: 1.0,
            pourSeconds: 60,
          ),
        ],
      );

      final session = BrewSessionService();
      session
          .obtain(
            brew,
            cuePlayer: _SilentCuePlayer(),
            scheduler: scheduler,
            clock: () => currentTime,
          )
          .start();
      await settle(tester);

      // 1. Brew floater is visible on Step 1 (Bloom · pour to 60g).
      expect(find.byKey(const Key('brew-floater')), findsOneWidget);
      expect(find.text('Bloom · pour to 60g'), findsOneWidget);

      // 2. Hide app in background and simulate OS memory eviction.
      await hideAppInBackground(tester);
      session.suspendInMemory();
      expect(session.active.value, isNull);

      // 3. Advance clock by 55 seconds (10s into Step 2) so Step 1's notification appears.
      currentTime = currentTime.add(const Duration(seconds: 55));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);
      final brewNotification = appeared.first;
      expect(brewNotification.payload, equals('brew:${brew.id}'));

      // 4. User clicks the brew notification to open the app.
      await tapNotificationAndOpenApp(tester, brewNotification);

      // 5. App opens with the running brew-floater visible on Step 2 (Main pour · pour to 320g)!
      expect(session.hasBrewInProgress, isTrue);
      expect(find.byKey(const Key('brew-floater')), findsOneWidget);
      expect(find.text('Main pour · pour to 320g'), findsOneWidget);
      expect(find.text('1:50'), findsOneWidget);

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Activity run during preparation countdown: hide app in background -> notification appears -> click notification -> opens app with running activity-floater showing caught-up step',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final routineWithPrep = TimerSequence(
        id: 'sim-activity-prep',
        name: 'Tabata Sprint',
        preparationSeconds: 10,
        timers: [
          ActivityTimer(
            name: 'High Knees',
            durationInSeconds: 20,
            phase: IntervalPhase.work,
          ),
          ActivityTimer(
            name: 'Active Rest',
            durationInSeconds: 15,
            phase: IntervalPhase.rest,
          ),
        ],
      );

      final session = ActivitySessionService();
      session.obtain(
        routineWithPrep,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);

      // 1. Floating pill initially shows 'get ready' preparation countdown (0:10).
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(find.text('Tabata Sprint · get ready'), findsOneWidget);
      expect(find.text('0:10'), findsOneWidget);

      // 2. Hide app in background (+ OS memory eviction).
      await hideAppInBackground(tester);
      session.suspendInMemory();

      // 3. Advance clock by 35s (past 10s prep + 20s Step 1 -> 5s into Step 2).
      currentTime = currentTime.add(const Duration(seconds: 35));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);

      // 4. User clicks the notification to open the app.
      await tapNotificationAndOpenApp(tester, appeared.last);

      // 5. App opens with the running activity-floater showing Step 2 (Active Rest, 0:10 left).
      expect(session.hasSessionInProgress, isTrue);
      expect(find.byKey(const Key('activity-floater')), findsOneWidget);
      expect(find.text('Tabata Sprint · Active Rest'), findsOneWidget);
      expect(find.text('0:10'), findsOneWidget);

      session.clear();
      await settle(tester);
    },
  );

  testWidgets(
    'Interval alert on full IntervalTimerScreen: hide app in background -> alert notification appears -> click notification -> surfaces MainNavigation with running interval-floater showing',
    (tester) async {
      await pumpApp(tester);

      final scheduler = _RecordingAlarmScheduler();
      final alertTimer = IntervalTimer(
        id: 'sim-interval-full',
        name: 'Posture Check',
        startTime: currentTime.subtract(const Duration(minutes: 1)),
        endTime: currentTime.add(const Duration(minutes: 60)),
        intervalValue: 15,
        intervalType: IntervalType.minute,
      );

      final session = IntervalSessionService();
      session.obtain(
        alertTimer,
        cuePlayer: _SilentCuePlayer(),
        scheduler: scheduler,
        clock: () => currentTime,
      );
      await settle(tester);

      // Expand into the full-screen IntervalTimerScreen before backgrounding.
      await tester.tap(find.byKey(const Key('interval-floater')));
      await settle(tester);
      expect(find.text('till next alarm'), findsOneWidget);

      // Hide app in background.
      await hideAppInBackground(tester);

      // Advance clock by 16 minutes so alarm #2 notification appears.
      currentTime = currentTime.add(const Duration(minutes: 16));
      final appeared = scheduler.appearedNotificationsAt(currentTime);
      expect(appeared, isNotEmpty);

      // Click the notification to open the app.
      await tapNotificationAndOpenApp(tester, appeared.first);

      // MainNavigation is surfaced with the running interval-floater showing alarm 3 of 5.
      expect(find.byKey(const Key('interval-floater')), findsOneWidget);
      expect(find.text('Posture Check · alarm 3 of 5'), findsOneWidget);
      expect(session.hasSessionInProgress, isTrue);

      session.clear();
      await settle(tester);
    },
  );
}
