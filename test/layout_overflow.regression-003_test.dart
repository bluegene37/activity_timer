import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/navigation/main_navigation.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Regression: ISSUE-003 — the bottom nav bar clipped its own labels on
// 375pt-wide phones at the default text size, and the Activities header and
// Settings info rows overflowed horizontally at accessibility text scales.
// Found by /qa on 2026-08-31
// Report: .gstack/qa-reports/qa-report-activity-timer-2026-08-31.md
//
/// Pumps the whole shell at the smallest supported phone and at accessibility
/// text scales, visiting every tab, and fails on any RenderFlex overflow.
/// Layout overflow is the one bug class the other widget tests never assert
/// on, so it shipped unnoticed.
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
    tempDir = await Directory.systemTemp.createTemp('qa_overflow_sweep');
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const sizes = <String, Size>{
    'iPhone SE (320x568)': Size(320, 568),
    'iPhone 13 mini (375x812)': Size(375, 812),
    'iPhone 17 Pro (402x874)': Size(402, 874),
  };
  const scales = <double>[1.0, 1.3, 2.0];

  for (final entry in sizes.entries) {
    for (final scale in scales) {
      testWidgets('no overflow: ${entry.key} @ textScale ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        setUpLocator();

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const MainNavigation(),
            ),
          ),
        );
        await settle(tester);

        for (final tab in const [
          'Activities',
          'Brew',
          'Intervals',
          'Settings',
        ]) {
          await tester.tap(find.text(tab), warnIfMissed: false);
          await settle(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow on $tab at ${entry.key} @ ${scale}x',
          );
        }
      });
    }
  }
}
