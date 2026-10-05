import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/screens/interval_timer_list_screen.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:activity_timer/services/ui_messenger.dart';
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
    UiMessenger().recorder = null;
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

  // Gene - Oct, 06, 2026: Added widget test verifying "Your Interval Timers" alongside "Quick Presets" and the shortened "Every 15 min" blue tag in the list.
  testWidgets(
    'IntervalTimerListScreen displays full title beside Quick Presets and shortened interval tag in list',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final timer = IntervalTimer(
        name: '15-Min Sprint Drills',
        startTime: DateTime(2026, 10, 6, 9, 0),
        endTime: DateTime(2026, 10, 6, 17, 0),
        intervalValue: 15,
        intervalType: IntervalType.minute,
      );
      await tester.runAsync(
        () => DatabaseService().createIntervalTimer(timer),
      );
      addTearDown(
        () => tester.runAsync(
          () => DatabaseService().deleteIntervalTimer(timer.id),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: IntervalTimerListScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));



      // Verify the section header displays full title and quick presets button without ellipsis
      expect(find.text('Your Interval Timers'), findsOneWidget);
      expect(find.text('Quick Presets'), findsOneWidget);

      // Verify the list displays the item with the shortened blue tag "Every 15 min"
      expect(find.text('15-Min Sprint Drills'), findsOneWidget);
      expect(find.text('Every 15 min'), findsOneWidget);
      expect(find.text('Every 15 minutes'), findsNothing);
    },
  );
}
