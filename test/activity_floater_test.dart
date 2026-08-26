import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

TimerSequence routine() => TimerSequence(
  name: 'Gym Routine',
  preparationSeconds: 0,
  timers: [
    ActivityTimer(
      name: 'Squats',
      durationInSeconds: 600,
      phase: IntervalPhase.work,
    ),
  ],
);

/// The nav screens animate continuously, so pumpAndSettle never settles;
/// bounded pumps are the established idiom for this widget tree.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp('activity_floater_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    ActivitySessionService().clear();
    await resetLocator();
  });

  Future<void> pumpNav(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    setUpLocator();
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const MainNavigation()),
    );
    await settle(tester);
  }

  testWidgets('no floater when no routine runs', (tester) async {
    await pumpNav(tester);

    expect(find.byKey(const Key('activity-floater')), findsNothing);
  });

  testWidgets('a running session floats on every tab and expands on tap', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = ActivitySessionService();
    session.obtain(routine(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    // Chip visible on the Activities tab...
    expect(find.byKey(const Key('activity-floater')), findsOneWidget);
    expect(find.textContaining('Gym Routine'), findsOneWidget);

    // ...and still there on another tab.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.byKey(const Key('activity-floater')), findsOneWidget);

    // Tapping expands the full run screen on the same session.
    await tester.tap(find.byKey(const Key('activity-floater')));
    await settle(tester);
    expect(find.text('remaining'), findsOneWidget);

    session.clear();
    await settle(tester);
  });

  testWidgets('minimizing the run screen keeps the session and the chip', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = ActivitySessionService();
    final controller = session.obtain(routine(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    await tester.tap(find.byKey(const Key('activity-floater')));
    await settle(tester);
    expect(find.text('remaining'), findsOneWidget);

    // Minimize via the chevron.
    await tester.tap(find.byTooltip('Minimize'));
    await settle(tester);

    expect(
      session.active.value,
      same(controller),
      reason: 'session survives the pop',
    );
    expect(controller.isRunning.value, isTrue);
    expect(find.byKey(const Key('activity-floater')), findsOneWidget);

    session.clear();
    await settle(tester);
  });

  testWidgets('the chip close button ends the session', (tester) async {
    await pumpNav(tester);

    final session = ActivitySessionService();
    session.obtain(routine(), cuePlayer: _SilentCuePlayer());
    await settle(tester);
    expect(find.byKey(const Key('activity-floater')), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-floater-close')));
    await settle(tester);

    expect(session.active.value, isNull);
    expect(find.byKey(const Key('activity-floater')), findsNothing);
  });

  testWidgets('the End button on the run screen confirms, then ends', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = ActivitySessionService();
    session.obtain(routine(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    await tester.tap(find.byKey(const Key('activity-floater')));
    await settle(tester);

    await tester.tap(find.byTooltip('End routine'));
    await settle(tester);
    expect(find.text('Exit Activity?'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await settle(tester);

    expect(session.active.value, isNull);
    expect(find.byKey(const Key('activity-floater')), findsNothing);
  });
}
