import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/screens/brew_edit_screen.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('brew_edit_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(Get.reset);

  BrewRecipe recipe() => BrewRecipe(
    name: 'Morning V60',
    method: BrewMethod.v60,
    doseGrams: 20,
    ratio: 16,
    steps: [
      BrewStep(
        name: 'Bloom',
        seconds: 30,
        pourToFraction: 0.1875,
        pourSeconds: 10,
      ),
      BrewStep(
        name: 'Main pour',
        seconds: 45,
        pourToFraction: 1,
        pourSeconds: 20,
      ),
    ],
  );

  testWidgets('shows targets in grams, never fractions', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: BrewEditScreen(recipe: recipe(), isNew: false)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('320g'), findsWidgets, reason: '20g x 16');
    expect(
      find.textContaining('60'),
      findsWidgets,
      reason: 'bloom target in grams',
    );
    expect(find.textContaining('0.1875'), findsNothing);
  });

  testWidgets('changing the dose restates every target', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: BrewEditScreen(recipe: recipe(), isNew: false)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('brew-dose-field')), '30');
    await tester.pumpAndSettle();

    expect(find.textContaining('480g'), findsWidgets);
  });

  testWidgets('blocks a save that breaks an invariant', (tester) async {
    final broken = recipe();
    broken.steps[1].pourToFraction = 0.5; // last pour no longer reaches total

    await tester.pumpWidget(
      GetMaterialApp(home: BrewEditScreen(recipe: broken, isNew: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('last pour must reach the full water total'),
      findsOneWidget,
    );
    expect(await DatabaseService().getBrewRecipe(broken.id), isNull);
  });

  testWidgets('saves a valid recipe and pops with true', (tester) async {
    final fresh = recipe();

    await tester.pumpWidget(
      GetMaterialApp(home: BrewEditScreen(recipe: fresh, isNew: true)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('brew-name-field')),
      'Sunday V60',
    );
    // The save writes to Hive, and that write is real disk IO. Starting it
    // outside runAsync leaves its completion dangling in the fake-async test
    // zone: the read-back below still eventually sees the row, but the write
    // never fully unwinds, so `Hive.close()` in tearDownAll hangs forever.
    // Both the tap that triggers the write and a short settling delay have to
    // run inside the same runAsync call so the write starts and lands in the
    // real zone.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final stored = await DatabaseService().getBrewRecipe(fresh.id);
      expect(stored, isNotNull);
      expect(stored!.name, 'Sunday V60');
      expect(stored.targetGramsAt(1), 320);
    });
  });
}
