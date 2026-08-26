import 'dart:async';
import 'dart:io';

import 'package:activity_timer/controllers/interval_timer_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/routes/app_routes.dart';
import 'package:activity_timer/screens/brew_edit_screen.dart';
import 'package:activity_timer/screens/brew_run_screen.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:activity_timer/services/ui_messenger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

/// go_router's `extra` is `Object?`, so a route builder casting it to a
/// concrete type compiles fine no matter what a caller passes, and only
/// blows up when the page is built. These tests pin the argument contract
/// for every route that takes one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // Pushing a run route now builds the real screen, which reaches for
    // audio and the wakelock.
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

    tempDir = await Directory.systemTemp.createTemp('app_routes_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(setUpLocator);

  tearDown(resetLocator);

  IntervalTimer sampleIntervalTimer() {
    final start = DateTime(2026, 1, 1, 8);
    return IntervalTimer(
      name: 'Hourly Check-in',
      startTime: start,
      endTime: start.add(const Duration(hours: 4)),
      intervalValue: 1,
      intervalType: IntervalType.hour,
    );
  }

  BrewRecipe sampleBrew() => BrewRecipe(
    name: 'Morning V60',
    method: BrewMethod.v60,
    doseGrams: 18,
    ratio: 16,
    steps: [
      BrewStep(
        name: 'Bloom',
        seconds: 45,
        pourToFraction: 0.12,
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

  /// Pumps the real router, then pushes [route] carrying [arguments].
  Future<void> pushRoute(
    WidgetTester tester,
    String route,
    Object? arguments,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: AppPages.createRouter()),
    );
    await tester.pumpAndSettle();
    unawaited(AppPages.push<void>(route, extra: arguments));
    await tester.pumpAndSettle();
  }

  test('every declared route is registered exactly once', () {
    const names = [
      Routes.home,
      Routes.timerList,
      Routes.timer,
      Routes.editTimer,
      Routes.intervalTimer,
      Routes.editIntervalTimer,
      Routes.editBrew,
      Routes.brew,
      Routes.settings,
    ];

    final declared =
        AppPages.routes
            .whereType<GoRoute>()
            .map((route) => route.path)
            .toList();

    for (final name in names) {
      expect(
        declared.where((path) => path == name),
        hasLength(1),
        reason: 'route $name should be declared exactly once',
      );
    }
  });

  testWidgets('editIntervalTimer builds from an EditIntervalTimerArgs record', (
    tester,
  ) async {
    await pushRoute(tester, Routes.editIntervalTimer, (
      timer: sampleIntervalTimer(),
      isNew: true,
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Interval Settings'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
  });

  testWidgets('editIntervalTimer surfaces the timer it was handed', (
    tester,
  ) async {
    final timer = sampleIntervalTimer();
    await pushRoute(tester, Routes.editIntervalTimer, (
      timer: timer,
      isNew: false,
    ));

    expect(tester.takeException(), isNull);
    expect(find.text(timer.name), findsWidgets);
  });

  testWidgets('editBrew builds from an EditBrewArgs record', (tester) async {
    await pushRoute(tester, Routes.editBrew, (
      recipe: sampleBrew(),
      isNew: true,
    ));

    expect(tester.takeException(), isNull);
    expect(find.byType(BrewEditScreen), findsOneWidget);
  });

  testWidgets('brew builds from a BrewRecipe argument', (tester) async {
    await pushRoute(tester, Routes.brew, sampleBrew());

    expect(tester.takeException(), isNull);
    expect(find.byType(BrewRunScreen), findsOneWidget);
  });

  // A push that opens an editor and acts on its result: these pin the
  // round trip, which is where a wrong argument shape or a mishandled
  // result would show up.
  testWidgets('addNewIntervalTimer opens the edit screen and reloads on save', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: AppPages.createRouter()),
    );
    await tester.pumpAndSettle();

    setUpLocator();
    final controller = locator<IntervalTimerController>();
    final pending = controller.addNewIntervalTimer();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Interval Settings'), findsOneWidget);

    // Stand in for the edit screen's own save, so a reload is observable.
    final saved = sampleIntervalTimer();
    await tester.runAsync(() => DatabaseService().createIntervalTimer(saved));

    UiMessenger().navigatorKey.currentState!.pop(true);
    await tester.pumpAndSettle();
    await pending;

    expect(tester.takeException(), isNull);
    expect(
      controller.intervalTimers.map((timer) => timer.id),
      contains(saved.id),
    );
  });
}
