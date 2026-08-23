import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// The route table casts `Get.arguments` to a concrete type, so a caller that
/// passes the wrong shape (a `Map` where a record is expected, say) compiles
/// fine and only blows up when the page is built. These tests pin the
/// argument contract for the routes that take one.
void main() {
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
}
