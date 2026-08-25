import 'dart:io';

import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/services/brew_cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

class _SilentCuePlayer implements BrewCuePlayer {
  @override
  Future<void> playStepEnd(AlarmSound sound) async {}

  @override
  Future<void> playCompleted() async {}

  @override
  Future<void> dispose() async {}
}

IntervalTimer timer() {
  final now = DateTime.now();
  return IntervalTimer(
    name: 'Stretch break',
    startTime: now.subtract(const Duration(minutes: 1)),
    endTime: now.add(const Duration(minutes: 30)),
    intervalValue: 5,
    intervalType: IntervalType.minute,
  );
}

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

    tempDir = await Directory.systemTemp.createTemp('interval_floater_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() {
    IntervalSessionService().clear();
    Get.reset();
  });

  Future<void> pumpNav(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Get.put(AppController());
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const MainNavigation()),
    );
    await settle(tester);
  }

  testWidgets('no floater when no interval session runs', (tester) async {
    await pumpNav(tester);

    expect(find.byKey(const Key('interval-floater')), findsNothing);
  });

  testWidgets('a running session floats on every tab and expands on tap', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = IntervalSessionService();
    session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    // Chip visible on the Activities tab...
    expect(find.byKey(const Key('interval-floater')), findsOneWidget);
    expect(find.textContaining('Stretch break'), findsOneWidget);

    // ...and still there on another tab.
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.byKey(const Key('interval-floater')), findsOneWidget);

    // Tapping expands the full run screen on the same session.
    await tester.tap(find.byKey(const Key('interval-floater')));
    await settle(tester);
    expect(find.text('till next alarm'), findsOneWidget);

    session.clear();
    await settle(tester);
  });

  testWidgets('minimizing the run screen keeps the session and the chip', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = IntervalSessionService();
    final controller = session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    await tester.tap(find.byKey(const Key('interval-floater')));
    await settle(tester);
    expect(find.text('till next alarm'), findsOneWidget);

    // Minimize via the chevron.
    await tester.tap(find.byTooltip('Minimize'));
    await settle(tester);

    expect(
      session.active.value,
      same(controller),
      reason: 'session survives the pop',
    );
    expect(controller.isRunning.value, isTrue);
    expect(find.byKey(const Key('interval-floater')), findsOneWidget);

    session.clear();
    await settle(tester);
  });

  testWidgets('the chip close button ends the session', (tester) async {
    await pumpNav(tester);

    final session = IntervalSessionService();
    session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    await settle(tester);
    expect(find.byKey(const Key('interval-floater')), findsOneWidget);

    await tester.tap(find.byKey(const Key('interval-floater-close')));
    await settle(tester);

    expect(session.active.value, isNull);
    expect(find.byKey(const Key('interval-floater')), findsNothing);
  });

  testWidgets('the End button on the run screen confirms, then ends', (
    tester,
  ) async {
    await pumpNav(tester);

    final session = IntervalSessionService();
    session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    await settle(tester);

    await tester.tap(find.byKey(const Key('interval-floater')));
    await settle(tester);

    await tester.tap(find.byTooltip('End timer'));
    await settle(tester);
    expect(find.text('Exit Timer?'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await settle(tester);

    expect(session.active.value, isNull);
    expect(find.byKey(const Key('interval-floater')), findsNothing);
  });
}
