import 'dart:io';

import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:activity_timer/screens/activity_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('activity_list_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ActivityTimerAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TimerSequenceAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SessionHistoryAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(IntervalPhaseAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'ActivityListScreen renders header, category filter chips, search, and preset button',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const GetMaterialApp(home: ActivityListScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Activity Timer'), findsOneWidget);
      expect(find.text('All Routines'), findsOneWidget);
      expect(find.text('Fitness & Sports'), findsOneWidget);
      expect(find.text('Work & Focus'), findsOneWidget);
      expect(find.text('Explore Presets'), findsOneWidget);
    },
  );
}
