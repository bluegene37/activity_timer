import 'dart:io';

import 'package:activity_timer/controllers/brew_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/routes/app_pages.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('brew_controller_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    await resetLocator();
    for (final recipe in await DatabaseService().getAllBrewRecipes()) {
      await DatabaseService().deleteBrewRecipe(recipe.id);
    }
  });

  testWidgets('addFromTemplate stores an editable copy and reloads', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const Scaffold()),
    );
    await tester.pumpAndSettle();

    setUpLocator();
    final controller = locator<BrewController>();
    final template = DatabaseService().getBrewTemplates().first;

    // `addFromTemplate` ends in `Get.snackbar`, and the Hive write ahead of it
    // only progresses for real inside `runAsync`. That puts the snackbar's
    // auto-dismiss timer on a *real* clock too. If it isn't closed before
    // leaving this real-async zone, that timer outlives the test and fires
    // mid-navigation in whichever test runs next, corrupting GetX's route
    // bookkeeping — the next test's `Get.toNamed`/`Get.back` pair then hangs
    // forever instead of failing. Close it here, in the same zone that
    // raised it.
    await tester.runAsync(() async {
      await controller.addFromTemplate(template);
    });
    await tester.pumpAndSettle();

    expect(controller.recipes, hasLength(1));
    expect(controller.recipes.first.name, template.name);
    expect(controller.recipes.first.id, isNot(template.id));
  });

  testWidgets('deleteBrew removes the recipe from the list and the box', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const Scaffold()),
    );
    await tester.pumpAndSettle();

    setUpLocator();
    final controller = locator<BrewController>();
    final template = DatabaseService().getBrewTemplates().first;
    // See the comment on the previous test: close the snackbar in the same
    // real-async zone that raised it, or its timer outlives this test.
    await tester.runAsync(() async {
      await controller.addFromTemplate(template);
    });
    final id = controller.recipes.first.id;

    await tester.runAsync(() => controller.deleteBrew(id));
    await tester.pumpAndSettle();

    expect(controller.recipes, isEmpty);
    await tester.runAsync(() async {
      expect(await DatabaseService().getBrewRecipe(id), isNull);
    });
  });

  testWidgets('addNewBrew opens the editor and reloads when it saves', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(getPages: AppPages.routes, home: const Scaffold()),
    );
    await tester.pumpAndSettle();

    setUpLocator();
    final controller = locator<BrewController>();
    final pending = controller.addNewBrew();
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'named routes must be pushed untyped',
    );
    expect(Get.currentRoute, '/edit-brew');

    final saved = BrewController.starterRecipe()..name = 'Saved from editor';
    await tester.runAsync(() => DatabaseService().createBrewRecipe(saved));
    Get.back<bool>(result: true);
    await tester.pumpAndSettle();
    await pending;

    expect(controller.recipes.map((r) => r.id), contains(saved.id));
  });

  test('starterRecipe is valid out of the box', () {
    expect(BrewController.starterRecipe().validationErrors(), isEmpty);
  });
}
