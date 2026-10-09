import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/main.dart';
import 'package:activity_timer/models/settings.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:activity_timer/theme/app_theme.dart';
import 'package:activity_timer/theme/brew_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:signals/signals_flutter.dart';
// Gene - Oct, 9, 2026: Added import for BrewListScreen testing.
import 'package:activity_timer/screens/brew_list_screen.dart';

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

  tearDown(resetLocator);

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
      setUpLocator();
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
      setUpLocator();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Literata'));
    expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFF2EDE3)));
  });

  test('coffee and iOS themes can animate into each other', () {
    // MaterialApp lerps ThemeData over ~200ms on a theme switch;
    // TextStyle.lerp throws when two styles disagree on `inherit`. This
    // walks every slot of both text themes in both brightnesses, which is
    // exactly what the transition frames do.
    for (final brightness in Brightness.values) {
      final ios =
          brightness == Brightness.dark
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

  test('button text styles agree on inherit across themes', () {
    // ThemeData.lerp being safe is not enough: each button's
    // AnimatedDefaultTextStyle lerps the RESOLVED button text style, which
    // falls back to labelLarge when a button theme omits textStyle. Both
    // themes must resolve to styles with the same `inherit` flag.
    TextStyle? resolved(ThemeData theme) =>
        theme.elevatedButtonTheme.style?.textStyle?.resolve(const {}) ??
        theme.textTheme.labelLarge;

    for (final brightness in Brightness.values) {
      final ios =
          brightness == Brightness.dark
              ? AppTheme.getDarkTheme(AppSettings.defaultThemeColor)
              : AppTheme.getLightTheme(AppSettings.defaultThemeColor);
      final coffee = BrewTheme.themeFor(brightness);

      final iosStyle = resolved(ios);
      final coffeeStyle = resolved(coffee);
      expect(iosStyle, isNotNull);
      expect(coffeeStyle, isNotNull);
      expect(
        coffeeStyle!.inherit,
        iosStyle!.inherit,
        reason: 'mismatched inherit throws in TextStyle.lerp ($brightness)',
      );
      expect(
        () => TextStyle.lerp(iosStyle, coffeeStyle, 0.3),
        returnsNormally,
        reason: 'button text must lerp across the theme switch ($brightness)',
      );
    }
  });

  testWidgets('switching themes animates buttons without lerp errors', (
    tester,
  ) async {
    // The crash only reproduces in the real widget pipeline: MaterialApp
    // animates the theme change over ~200ms and every button's
    // AnimatedDefaultTextStyle lerps its old resolved text style into the
    // new one. Pump mid-animation frames in both directions and demand
    // silence.
    final style = signal(AppThemeStyle.ios);

    await tester.pumpWidget(
      SignalBuilder(
        builder:
            (_) => MaterialApp(
              theme:
                  style.value == AppThemeStyle.coffee
                      ? BrewTheme.themeFor(Brightness.light)
                      : AppTheme.getLightTheme(AppSettings.defaultThemeColor),
              home: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
      ),
    );
    await tester.pump();

    for (final next in [AppThemeStyle.coffee, AppThemeStyle.ios]) {
      style.value = next;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.takeException(),
        isNull,
        reason: 'mid-animation frames switching to $next must not throw',
      );
      await tester.pumpAndSettle();
    }
  });

  // Gene - Oct, 9, 2026: Added tests verifying that BrewListScreen inherits the Modern theme
  // when themeStyle is AppThemeStyle.ios and the Coffee theme when themeStyle is AppThemeStyle.coffee.
  testWidgets('Brew screen is affected by Modern theme when AppThemeStyle.ios', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await AppSettings().setThemeStyle(AppThemeStyle.ios);
      setUpLocator();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Brew tab
    await tester.tap(find.text('Brew'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(BrewListScreen),
        matching: find.byType(Scaffold),
      ),
    );
    // Modern theme scaffold background (not washi paper)
    expect(scaffold.backgroundColor, isNot(const Color(0xFFF2EDE3)));
    expect(scaffold.backgroundColor, isNot(const Color(0xFF1B1815)));
  });

  testWidgets('Brew screen wears Coffee washi theme when AppThemeStyle.coffee', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await AppSettings().setThemeStyle(AppThemeStyle.coffee);
      setUpLocator();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Brew tab
    await tester.tap(find.text('Brew'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(BrewListScreen),
        matching: find.byType(Scaffold),
      ),
    );
    // Coffee theme washi paper background
    expect(
      scaffold.backgroundColor,
      anyOf(const Color(0xFFF2EDE3), const Color(0xFF1B1815)),
    );
  });
}
