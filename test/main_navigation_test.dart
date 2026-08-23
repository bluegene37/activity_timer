import 'dart:io';

import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
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

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'MainNavigation shows New Routine FAB on Activities, New Interval on Intervals, and hides FAB on Settings',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Get.put(AppController());

      await tester.pumpWidget(const GetMaterialApp(home: MainNavigation()));
      await tester.pumpAndSettle();

      // Tab 0: Activities -> New Routine FAB is visible
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Intervals'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('New Routine'), findsOneWidget);
      expect(find.text('New Interval'), findsNothing);

      // Tap Intervals Tab
      await tester.tap(find.text('Intervals'));
      await tester.pumpAndSettle();

      // Tab 1: Intervals -> New Interval FAB is visible, New Routine is gone
      expect(find.text('New Interval'), findsOneWidget);
      expect(find.text('New Routine'), findsNothing);

      // Tap Settings Tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tab 2: Settings -> No FAB is visible
      expect(find.text('New Interval'), findsNothing);
      expect(find.text('New Routine'), findsNothing);
      expect(find.text('Theme Mode'), findsOneWidget);

      // Switch back to Activities
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      expect(find.text('New Routine'), findsOneWidget);
      expect(find.text('New Interval'), findsNothing);
    },
  );
}
