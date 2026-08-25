import 'dart:io';

import 'package:activity_timer/controllers/app_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/main.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/theme/app_theme.dart';
import 'package:activity_timer/theme/brew_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('coffee_theme_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(Get.reset);

  test('themeStyle persists and defaults to coffee', () async {
    final settings = AppSettings();
    await settings.loadSettings();
    expect(settings.themeStyle, AppThemeStyle.coffee, reason: 'default style');

    await settings.setThemeStyle(AppThemeStyle.ios);
    expect(settings.themeStyle, AppThemeStyle.ios);

    // A fresh load must read the persisted value back.
    await settings.loadSettings();
    expect(settings.themeStyle, AppThemeStyle.ios);

    await settings.setThemeStyle(AppThemeStyle.coffee);
  });

  testWidgets('coffee style paints the whole app washi', (tester) async {
    // Hive IO only progresses outside the fake-async zone.
    await tester.runAsync(() async {
      await AppSettings().setThemeStyle(AppThemeStyle.coffee);
      Get.put(AppController());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Literata');
    // Washi paper in whichever brightness the app resolved.
    expect(
      theme.scaffoldBackgroundColor,
      anyOf(const Color(0xFFF2EDE3), const Color(0xFF1B1815)),
    );
  });

  testWidgets('ios style keeps the existing look', (tester) async {
    await tester.runAsync(() async {
      await AppSettings().setThemeStyle(AppThemeStyle.ios);
      Get.put(AppController());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Literata'));
    expect(
      theme.scaffoldBackgroundColor,
      isNot(const Color(0xFFF2EDE3)),
    );
  });

  test('coffee and iOS themes can animate into each other', () {
    // MaterialApp lerps ThemeData over ~200ms on a theme switch;
    // TextStyle.lerp throws when two styles disagree on `inherit`. This
    // walks every slot of both text themes in both brightnesses, which is
    // exactly what the transition frames do.
    for (final brightness in Brightness.values) {
      final ios = brightness == Brightness.dark
          ? AppTheme.getDarkTheme(AppSettings.defaultThemeColor)
          : AppTheme.getLightTheme(AppSettings.defaultThemeColor);
      final coffee = BrewTheme.themeFor(brightness);

      expect(
        () => ThemeData.lerp(ios, coffee, 0.3),
        returnsNormally,
        reason: 'theme switch must be lerp-safe ($brightness)',
      );
    }
  });
}
