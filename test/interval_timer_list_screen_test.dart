import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/screens/interval_timer_list_screen.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('interval_timer_list_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(setUpLocator);

  tearDown(() async {
    await resetLocator();
  });

  testWidgets(
    'IntervalTimerListScreen shows Quick Presets button and opens searchable bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: IntervalTimerListScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Interval Timers'), findsOneWidget);
      expect(find.text('Quick Presets'), findsOneWidget);

      // Tap Quick Presets to open the bottom sheet
      await tester.tap(find.text('Quick Presets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Modal sheet is visible with title and search
      expect(find.text('Interval Presets'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Hourly Boss Check-in'), findsOneWidget);
      expect(find.text('Stand & Hydrate Ping'), findsOneWidget);

      // Search for 'Hydrate'
      await tester.enterText(find.byType(TextField), 'Hydrate');
      await tester.pump();

      expect(find.text('Stand & Hydrate Ping'), findsOneWidget);
      expect(find.text('Hourly Boss Check-in'), findsNothing);
    },
  );
}
