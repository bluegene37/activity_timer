import 'dart:io';
import 'dart:math' as math;

import 'package:activity_timer/controllers/activity_list_controller.dart';
import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/controllers/brew_run_controller.dart';
import 'package:activity_timer/controllers/interval_run_controller.dart';
import 'package:activity_timer/controllers/interval_timer_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
import 'package:activity_timer/screens/brew_edit_screen.dart';
import 'package:activity_timer/screens/brew_run_screen.dart';
import 'package:activity_timer/screens/edit_interval_timer_screen.dart';
import 'package:activity_timer/screens/edit_timer_screen.dart';
import 'package:activity_timer/screens/interval_timer_screen.dart';
import 'package:activity_timer/screens/settings_screen.dart';
import 'package:activity_timer/screens/timer_list_screen.dart';
import 'package:activity_timer/screens/timer_screen.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/brew_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:activity_timer/services/ui_messenger.dart';
import 'package:activity_timer/theme/app_theme.dart';
import 'package:activity_timer/theme/brew_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

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

class _NoopAlarmScheduler implements AlarmScheduler {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {}

  @override
  Future<void> cancelAll() async {}
}

class _FakeNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  _FakeNotificationsPlugin(this._launchDetails);

  final NotificationAppLaunchDetails? _launchDetails;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async =>
      _launchDetails;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;
}

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void _expectLiveRegion(WidgetTester tester, String screenName) {
  final finder = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.liveRegion == true,
  );
  expect(
    finder,
    findsWidgets,
    reason: '$screenName should mount Semantics(liveRegion: true)',
  );
  expect(
    tester
        .getSemantics(finder.first)
        .getSemanticsData()
        .flagsCollection
        .isLiveRegion,
    isTrue,
    reason: '$screenName SemanticsNode should set isLiveRegion',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

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
          (message) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp('qa_remediation_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    setUpLocator();
    UiMessenger().recorder = <String>[];
  });

  tearDown(() async {
    ActivitySessionService().clear();
    IntervalSessionService().clear();
    BrewSessionService().clear();
    UiMessenger().recorder = null;
    await resetLocator();
  });

  TimerSequence sampleSequence() => TimerSequence(
    id: 'qa-seq-1',
    name: 'Focus Sprint',
    preparationSeconds: 0,
    timers: [
      ActivityTimer(
        id: 'qa-step-1',
        name: 'Warmup',
        durationInSeconds: 60,
        phase: IntervalPhase.prepare,
      ),
      ActivityTimer(
        id: 'qa-step-2',
        name: 'Deep Work',
        durationInSeconds: 90,
        phase: IntervalPhase.work,
        description: 'Stay focused without distractions',
      ),
    ],
  );

  BrewRecipe sampleBrew() => BrewRecipe(
    id: 'qa-brew-1',
    name: 'Morning V60',
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
        name: 'Final pour',
        seconds: 45,
        pourToFraction: 1.0,
        pourSeconds: 20,
      ),
    ],
  );

  IntervalTimer sampleInterval({
    String id = 'qa-int-1',
    bool isActive = true,
    int intervalValue = 15,
  }) {
    final now = DateTime(2026, 11, 14, 9, 0);
    return IntervalTimer(
      id: id,
      name: 'Stretch Break',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      intervalValue: intervalValue,
      intervalType: IntervalType.minute,
      isActive: isActive,
    );
  }

  group('[QA-001] Untyped Map Deserialization', () {
    test('TimerSequence.fromJson handles untyped Hive maps and num doubles', () {
      final rawJson = <String, dynamic>{
        'id': 'seq-hive',
        'name': 'Restored',
        'preparationSeconds': 5.0,
        'timers': <dynamic>[
          <dynamic, dynamic>{
            'id': 't1',
            'name': 'Step 1',
            'durationInSeconds': 45.0,
            'phase': 'work',
          },
          'ignored-non-map-entry',
        ],
      };

      final seq = TimerSequence.fromJson(rawJson);
      expect(seq.name, 'Restored');
      expect(seq.preparationSeconds, 5);
      expect(seq.timers, hasLength(1));
      expect(seq.timers.first.durationInSeconds, 45);
      expect(seq.timers.first.phase, IntervalPhase.work);
    });
  });

  group('[QA-003] Cold-start Notification ActionId & Brew Snooze Policy', () {
    testWidgets('initializeAndCheckLaunch forwards actionId to handlePayload', (
      tester,
    ) async {
      try {
        final now = DateTime(2026, 11, 14, 12, 0);
        final seq = sampleSequence();
        final controller = ActivitySessionService().obtain(
          seq,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => now,
        );

        final fakePlugin = _FakeNotificationsPlugin(
          NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotificationAction,
              actionId: LocalNotificationAlarmScheduler.snooze5mActionId,
              payload: 'activity:${seq.id}',
            ),
          ),
        );

        await tester.runAsync(() async {
          await LocalNotificationAlarmScheduler.initializeAndCheckLaunch(
            plugin: fakePlugin,
          );
        });
        tester.binding.scheduleFrame();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.isRunning.value, isTrue);
        expect(controller.remainingMs.value, closeTo(300000, 1000));
      } finally {
        ActivitySessionService().clear();
      }
    });

    test('brew notifications omit snooze action while activity retains it', () {
      final alarm = ScheduledAlarm(
        id: 1,
        at: DateTime(2026, 11, 14, 12, 5),
        title: 'Timer',
        body: 'Done',
        sound: AlarmSound.beep,
        isCompletion: true,
      );

      final brewScheduler = LocalNotificationAlarmScheduler(
        idBase: LocalNotificationAlarmScheduler.brewIdBase,
      );
      final brewDetails = brewScheduler.detailsForTesting(alarm);
      final brewActionIds =
          (brewDetails.android?.actions ?? const []).map((a) => a.id).toList();
      expect(
        brewActionIds,
        isNot(contains(LocalNotificationAlarmScheduler.snooze5mActionId)),
      );
      expect(
        brewActionIds,
        contains(LocalNotificationAlarmScheduler.dismissActionId),
      );
      expect(
        brewDetails.iOS?.categoryIdentifier,
        LocalNotificationAlarmScheduler.brewCategoryId,
      );

      final activityScheduler = LocalNotificationAlarmScheduler();
      final activityDetails = activityScheduler.detailsForTesting(alarm);
      final activityActionIds =
          (activityDetails.android?.actions ?? const [])
              .map((a) => a.id)
              .toList();
      expect(
        activityActionIds,
        containsAll([
          LocalNotificationAlarmScheduler.snooze5mActionId,
          LocalNotificationAlarmScheduler.dismissActionId,
        ]),
      );
      expect(
        activityDetails.iOS?.categoryIdentifier,
        LocalNotificationAlarmScheduler.alarmCategoryId,
      );
    });
  });

  group('[QA-004] Interval Session Armed Flag Sync & Edit Refresh', () {
    test('clear, completion, reset, snooze, and refreshIfActive sync isActive', () async {
      var now = DateTime(2026, 11, 14, 9, 0);
      final baseTimer = IntervalTimer(
        id: 'qa-sync-1',
        name: 'Morning Check',
        startTime: now.add(const Duration(seconds: 10)),
        endTime: now.add(const Duration(seconds: 10)),
        intervalValue: 5,
        intervalType: IntervalType.minute,
        isPointInTime: true,
        isActive: true,
      );
      await DatabaseService().createIntervalTimer(baseTimer);
      final listCtrl = locator<IntervalTimerController>();
      await listCtrl.loadIntervalTimers();
      expect(listCtrl.intervalTimers.any((t) => t.id == baseTimer.id && t.isActive), isTrue);

      final session = IntervalSessionService();
      final runCtrl = session.obtain(
        baseTimer,
        cuePlayer: _SilentCuePlayer(),
        scheduler: _NoopAlarmScheduler(),
        clock: () => now,
      );
      expect(runCtrl.isCompleted.value, isFalse);

      // Completing the schedule disarms the timer in memory, list, and Hive.
      now = now.add(const Duration(seconds: 15));
      runCtrl.syncWithClock();
      await Future<void>.delayed(Duration.zero);
      expect(runCtrl.isCompleted.value, isTrue);
      expect(baseTimer.isActive, isFalse);
      expect(
        listCtrl.intervalTimers.firstWhere((t) => t.id == baseTimer.id).isActive,
        isFalse,
      );
      expect(
        (await DatabaseService().getIntervalTimer(baseTimer.id))?.isActive,
        isFalse,
      );

      // Snoozing re-arms the timer.
      runCtrl.snooze(const Duration(minutes: 5));
      await Future<void>.delayed(Duration.zero);
      expect(baseTimer.isActive, isTrue);
      expect(
        (await DatabaseService().getIntervalTimer(baseTimer.id))?.isActive,
        isTrue,
      );

      // Editing an active timer replaces the running controller with updated fields.
      final updated = IntervalTimer(
        id: baseTimer.id,
        name: 'Renamed Check',
        startTime: now.add(const Duration(minutes: 1)),
        endTime: now.add(const Duration(minutes: 31)),
        intervalValue: 10,
        intervalType: IntervalType.minute,
        isActive: true,
      );
      final refreshed = session.refreshIfActive(updated);
      expect(refreshed, isNotNull);
      expect(refreshed!.timer.name, 'Renamed Check');
      expect(refreshed.timer.intervalValue, 10);

      // Clearing ends the session and disarms isActive.
      session.clear();
      await Future<void>.delayed(Duration.zero);
      expect(session.active.value, isNull);
      expect(
        listCtrl.intervalTimers.firstWhere((t) => t.id == baseTimer.id).isActive,
        isFalse,
      );
      await DatabaseService().deleteIntervalTimer(baseTimer.id);
    });
  });

  group('[QA-005] Live Region Semantics', () {
    testWidgets('TimerScreen, IntervalTimerScreen, and BrewRunScreen expose liveRegion', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(home: TimerScreen(sequence: sampleSequence())),
        );
        await tester.pump();
        _expectLiveRegion(tester, 'TimerScreen');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        ActivitySessionService().clear();

        final timer = sampleInterval();
        final intervalCtrl = IntervalRunController(
          timer: timer,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => DateTime(2026, 11, 14, 9, 5),
        )..onInit();
        await tester.pumpWidget(
          MaterialApp(
            home: IntervalTimerScreen(timer: timer, controller: intervalCtrl),
          ),
        );
        await tester.pump();
        _expectLiveRegion(tester, 'IntervalTimerScreen');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        intervalCtrl.onClose();

        final brew = sampleBrew();
        final brewCtrl = BrewRunController(
          recipe: brew,
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => DateTime(2026, 11, 14, 9, 5),
        )..start();
        await tester.pumpWidget(
          MaterialApp(home: BrewRunScreen(recipe: brew, controller: brewCtrl)),
        );
        await tester.pump();
        _expectLiveRegion(tester, 'BrewRunScreen');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        brewCtrl.onClose();
      } finally {
        ActivitySessionService().clear();
        semanticsHandle.dispose();
      }
    });
  });

  group('[QA-006] [QA-007] [QA-014] Input & JSON Validation', () {
    testWidgets('BrewEditScreen validates cleared/zero Dose, Ratio, and Step seconds', (
      tester,
    ) async {
      final brew = sampleBrew();
      await tester.pumpWidget(
        MaterialApp(home: BrewEditScreen(recipe: brew, isNew: true)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('brew-dose-field')), '');
      await tester.enterText(find.byKey(const Key('brew-ratio-field')), '0');
      await tester.enterText(find.byKey(const Key('brew-step-0-seconds')), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dose must be greater than 0g.'), findsOneWidget);
      expect(find.textContaining('Ratio must be greater than 0.'), findsOneWidget);
      expect(find.byType(BrewEditScreen), findsOneWidget);
    });

    test('ActivityListController validates sequenceFromJson and importSequenceFromJson', () async {
      final emptyDefault = ActivityListController.sequenceFromJson('{}');
      expect(emptyDefault, isNotNull);

      expect(
        ActivityListController.sequenceFromJson(
          '{"name":"Bad Prep","preparationSeconds":-5,"timers":[{"name":"Step","durationInSeconds":30}]}',
        ),
        isNull,
      );
      expect(
        ActivityListController.sequenceFromJson(
          '{"name":"Zero Step","preparationSeconds":5,"timers":[{"name":"Step","durationInSeconds":0}]}',
        ),
        isNull,
      );

      final controller = locator<ActivityListController>();
      expect(await controller.importSequenceFromJson('{}'), isFalse);
      expect(
        await controller.importSequenceFromJson(
          '{"name":"Negative","preparationSeconds":0,"timers":[{"name":"S","durationInSeconds":-10}]}',
        ),
        isFalse,
      );
    });

    testWidgets('EditTimerScreen rejects whitespace Timer Name with inline error', (
      tester,
    ) async {
      final timer = ActivityTimer(
        name: 'Warmup',
        durationInSeconds: 30,
        phase: IntervalPhase.prepare,
      );
      await tester.pumpWidget(
        MaterialApp(home: EditTimerScreen(timer: timer)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text('Please enter a timer name'),
        ),
        findsOneWidget,
      );
      expect(find.byType(EditTimerScreen), findsOneWidget);
    });
  });

  group('[QA-009] Accessibility Tap Labels & Sizes', () {
    testWidgets('labeledTapTargetGuideline holds across shell, lists, and editors', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      try {
        await tester.pumpWidget(const MaterialApp(home: MainNavigation()));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        for (final tab in const ['Activities', 'Brew', 'Intervals', 'Settings']) {
          await tester.tap(find.text(tab));
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: 'labeledTapTargetGuideline failed on tab $tab',
          );
        }

        // Check remediated minimum 44x44 tap target sizing on MainNavigation FAB.
        await tester.tap(find.text('Activities'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(find.byType(FloatingActionButton)).height,
          greaterThanOrEqualTo(44.0),
        );

        await tester.pumpWidget(
          MaterialApp(home: TimerListScreen(sequence: sampleSequence())),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(
          tester.getSize(find.byTooltip('Edit Warmup')).width,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byTooltip('Edit Warmup')).height,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byTooltip('Delete Warmup')).height,
          greaterThanOrEqualTo(44.0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EditTimerScreen(
              timer: ActivityTimer(
                name: 'Focus',
                durationInSeconds: 60,
                phase: IntervalPhase.work,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await tester.pumpWidget(
          MaterialApp(
            home: EditIntervalTimerScreen(timer: sampleInterval(), isNew: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(
          tester.getSize(find.byTooltip('Decrease interval')).height,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byTooltip('Increase interval')).height,
          greaterThanOrEqualTo(44.0),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('[QA-011] [QA-012] WCAG AA Contrast & ThemeMode Clarifying Copy', () {
    test('AppTheme.onColor and light onSurfaceVariant meet 4.5:1 AA contrast', () {
      const accents = [
        AppTheme.iosBlue,
        AppTheme.iosGreen,
        AppTheme.iosIndigo,
        AppTheme.iosOrange,
        AppTheme.iosPink,
        AppTheme.iosPurple,
        AppTheme.iosRed,
        AppTheme.iosTeal,
        AppTheme.iosYellow,
        AppTheme.iosMint,
        AppTheme.iosCyan,
      ];
      for (final bg in accents) {
        final fg = AppTheme.onColor(bg);
        expect(
          _contrastRatio(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'onColor contrast < 4.5 for $bg (got $fg)',
        );
      }

      final lightTheme = AppTheme.getLightTheme(AppTheme.iosBlue);
      final variant = lightTheme.colorScheme.onSurfaceVariant;
      expect(_contrastRatio(variant, Colors.white), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(variant, const Color(0xFFF2F2F7)),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('SettingsScreen retains ThemeMode.light default and clarifies copy', (
      tester,
    ) async {
      expect(locator<AppController>().themeMode.value, ThemeMode.light);
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Defaults to Light; choose System to match device'),
        findsOneWidget,
      );
    });
  });

  group('[QA-002] [QA-008] [QA-010] [QA-013] Responsive Viewport x Theme x Scale Matrix', () {
    const viewports = <String, Size>{
      'compact_320x568': Size(320, 568),
      'phone_375x812': Size(375, 812),
      'landscape_812x375': Size(812, 375),
      'tablet_768x1024': Size(768, 1024),
    };
    const scales = <double>[1.0, 1.5, 2.0];

    Future<void> pumpScaled(
      WidgetTester tester, {
      required Size size,
      required double scale,
      required bool coffeeDark,
      required Widget child,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getLightTheme(AppTheme.iosYellow),
          darkTheme: BrewTheme.themeFor(Brightness.dark),
          themeMode: coffeeDark ? ThemeMode.dark : ThemeMode.light,
          builder:
              (context, widget) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: widget!,
              ),
          home: child,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('MainNavigation (4 tabs + 3 floaters) and modals have 0 overflows across 144 checks', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appCtrl = locator<AppController>();
      final now = DateTime(2026, 11, 14, 9, 5);
      var checks = 0;

      try {
        // Sub-sweep A (96 checks): 4 tabs x 24 viewport/scale/theme combos with all 3 floaters active.
        ActivitySessionService().obtain(
          sampleSequence(),
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => now,
        );
        IntervalSessionService().obtain(
          sampleInterval(),
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => now,
        );
        BrewSessionService().obtain(
          sampleBrew(),
          cuePlayer: _SilentCuePlayer(),
          scheduler: _NoopAlarmScheduler(),
          clock: () => now,
        );

        for (final vp in viewports.entries) {
          for (final scale in scales) {
            for (final coffeeDark in const [false, true]) {
              appCtrl.themeStyle.value =
                  coffeeDark ? AppThemeStyle.coffee : AppThemeStyle.ios;
              appCtrl.themeMode.value =
                  coffeeDark ? ThemeMode.dark : ThemeMode.light;

              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: const MainNavigation(),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'MainNavigation initial ${vp.key} @ ${scale}x dark=$coffeeDark',
              );

              for (final tab in const [
                'Activities',
                'Brew',
                'Intervals',
                'Settings',
              ]) {
                await tester.tap(find.text(tab).last);
                await tester.pump(const Duration(milliseconds: 50));
                await tester.pump(const Duration(milliseconds: 50));
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      'Overflow on tab $tab at ${vp.key} @ ${scale}x dark=$coffeeDark',
                );
                checks++;
              }
            }
          }
        }

        ActivitySessionService().clear();
        IntervalSessionService().clear();
        BrewSessionService().clear();

        // Sub-sweep B (48 checks): Quick Timer Custom & Interval Quick Presets modals x 24 combos.
        for (final vp in viewports.entries) {
          for (final scale in scales) {
            for (final coffeeDark in const [false, true]) {
              appCtrl.themeStyle.value =
                  coffeeDark ? AppThemeStyle.coffee : AppThemeStyle.ios;
              appCtrl.themeMode.value =
                  coffeeDark ? ThemeMode.dark : ThemeMode.light;

              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: const MainNavigation(),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'MainNavigation modal host ${vp.key} @ ${scale}x dark=$coffeeDark',
              );

              await tester.tap(find.text('Activities').last);
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Custom'));
              await tester.tap(find.text('Custom'));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Overflow in Quick Timer Custom sheet ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              checks++;
              await tester.tap(find.byTooltip('Close'));
              await tester.pumpAndSettle();
              await tester.pump(const Duration(milliseconds: 600));

              await tester.tap(find.text('Intervals').last);
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Quick Presets'));
              await tester.tap(find.text('Quick Presets'));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Overflow in Interval Quick Presets sheet ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              checks++;
              await tester.tap(find.byTooltip('Close'));
              await tester.pumpAndSettle();
            }
          }
        }

        expect(checks, 144);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 600));
      } finally {
        ActivitySessionService().clear();
        IntervalSessionService().clear();
        BrewSessionService().clear();
      }
    });

    testWidgets('Run and edit screens (+ SetDurationDialog) have 0 overflows across 120 checks', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var checks = 0;
      try {
        for (final vp in viewports.entries) {
          for (final scale in scales) {
            for (final coffeeDark in const [false, true]) {
              // 1. TimerScreen
              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: TimerScreen(sequence: sampleSequence()),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'TimerScreen overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              ActivitySessionService().clear();
              checks++;

              // 2. IntervalTimerScreen
              final iTimer = sampleInterval();
              final iCtrl = IntervalRunController(
                timer: iTimer,
                cuePlayer: _SilentCuePlayer(),
                scheduler: _NoopAlarmScheduler(),
                clock: () => DateTime(2026, 11, 14, 9, 5),
              )..onInit();
              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: IntervalTimerScreen(timer: iTimer, controller: iCtrl),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'IntervalTimerScreen overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              iCtrl.onClose();
              checks++;

              // 3. BrewRunScreen
              final brew = sampleBrew();
              final bCtrl = BrewRunController(
                recipe: brew,
                cuePlayer: _SilentCuePlayer(),
                scheduler: _NoopAlarmScheduler(),
                clock: () => DateTime(2026, 11, 14, 9, 5),
              )..start();
              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: BrewRunScreen(recipe: brew, controller: bCtrl),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'BrewRunScreen overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              bCtrl.onClose();
              checks++;

              // 4. BrewEditScreen
              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: BrewEditScreen(recipe: sampleBrew(), isNew: false),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'BrewEditScreen overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              checks++;

              // 5. EditTimerScreen + SetDurationDialog
              await pumpScaled(
                tester,
                size: vp.value,
                scale: scale,
                coffeeDark: coffeeDark,
                child: EditTimerScreen(
                  timer: ActivityTimer(
                    name: 'Step 1',
                    durationInSeconds: 60,
                    phase: IntervalPhase.work,
                  ),
                ),
              );
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'EditTimerScreen overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              await tester.ensureVisible(find.byIcon(CupertinoIcons.clock));
              await tester.tap(find.byIcon(CupertinoIcons.clock));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'SetDurationDialog overflow at ${vp.key} @ ${scale}x dark=$coffeeDark',
              );
              expect(find.text('Cancel'), findsOneWidget);
              await tester.tap(find.text('Cancel'));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              checks++;
            }
          }
        }
        expect(checks, 120);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        ActivitySessionService().clear();
        IntervalSessionService().clear();
        BrewSessionService().clear();
      }
    });
  });
}
