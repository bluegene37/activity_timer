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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

/// The route table casts `Get.arguments` to a concrete type, so a caller that
/// passes the wrong shape (a `Map` where a record is expected, say) compiles
/// fine and only blows up when the page is built. These tests pin the
/// argument contract for the routes that take one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('app_routes_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

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

  /// Pumps a GetX app whose only job is to push [route] with [arguments].
  Future<void> pushRoute(
    WidgetTester tester,
    String route,
    Object? arguments,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: AppPages.routes,
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () => Get.toNamed<void>(route, arguments: arguments),
                child: const Text('go'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
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

    for (final name in names) {
      expect(
        AppPages.routes.where((page) => page.name == name),
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

  // GetX generates every named route as `GetPageRoute<dynamic>`, so pushing one
  // with a concrete result type (`Get.toNamed<bool>`) blows up on a cast inside
  // `Navigator.pushNamed`. These pin the untyped push plus the `== true` narrowing.
  testWidgets('addNewIntervalTimer opens the edit screen and reloads on save', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const Scaffold()),
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

    Get.back<bool>(result: true);
    await tester.pumpAndSettle();
    await pending;

    expect(tester.takeException(), isNull);
    expect(
      controller.intervalTimers.map((timer) => timer.id),
      contains(saved.id),
    );
  });
}
