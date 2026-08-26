import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

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

    tempDir = await Directory.systemTemp.createTemp('main_nav_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    await resetLocator();
  });

  testWidgets(
    'MainNavigation shows New Routine FAB on Activities, New Interval on Intervals, and hides FAB on Settings',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      setUpLocator();

      await tester.pumpWidget(const GetMaterialApp(home: MainNavigation()));
      // This screen animates continuously, so pumpAndSettle never settles;
      // bounded pumps are the established idiom for this widget tree.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tab 0: Activities -> New Routine FAB is visible
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Intervals'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('New Routine'), findsOneWidget);
      expect(find.text('New Interval'), findsNothing);

      // Tap Intervals Tab
      await tester.tap(find.text('Intervals'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tab 1: Intervals -> New Interval FAB is visible, New Routine is gone
      expect(find.text('New Interval'), findsOneWidget);
      expect(find.text('New Routine'), findsNothing);

      // Tap Settings Tab
      await tester.tap(find.text('Settings'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tab 2: Settings -> No FAB is visible
      expect(find.text('New Interval'), findsNothing);
      expect(find.text('New Routine'), findsNothing);
      expect(find.text('Theme Mode'), findsOneWidget);

      // Switch back to Activities
      await tester.tap(find.text('Activities'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('New Routine'), findsOneWidget);
      expect(find.text('New Interval'), findsNothing);
    },
  );

  testWidgets('Brew tab sits second, between Activities and Intervals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    setUpLocator();

    await tester.pumpWidget(const GetMaterialApp(home: MainNavigation()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Brew'), findsOneWidget);

    // Pin the order: Activities < Brew < Intervals along the nav bar.
    final activitiesX = tester.getCenter(find.text('Activities')).dx;
    final brewX = tester.getCenter(find.text('Brew')).dx;
    final intervalsX = tester.getCenter(find.text('Intervals')).dx;
    expect(activitiesX, lessThan(brewX));
    expect(brewX, lessThan(intervalsX));

    await tester.tap(find.text('Brew'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('New Brew'), findsOneWidget);
    expect(find.text('New Interval'), findsNothing);

    await tester.tap(find.text('Settings'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('New Brew'), findsNothing);
  });
}
