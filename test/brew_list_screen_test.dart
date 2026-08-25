import 'dart:io';

import 'package:activity_timer/controllers/brew_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/screens/brew_list_screen.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('brew_list_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    Get.reset();
    for (final recipe in await DatabaseService().getAllBrewRecipes()) {
      await DatabaseService().deleteBrewRecipe(recipe.id);
    }
  });

  testWidgets('empty state invites the library', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: BrewListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Brew Library'), findsOneWidget);
  });

  testWidgets('a saved brew shows its dose, ratio, total and pour count', (
    tester,
  ) async {
    final template = DatabaseService().getBrewTemplates().firstWhere(
      (r) => r.name == 'Kalita Wave',
    );
    // Hive writes are real disk IO: they only complete inside runAsync.
    await tester.runAsync(
      () => DatabaseService().createBrewRecipe(template.cloneAsNew()),
    );

    await tester.pumpWidget(const GetMaterialApp(home: BrewListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kalita Wave'), findsOneWidget);
    expect(find.textContaining('20g'), findsWidgets);
    expect(find.textContaining('320g'), findsWidgets);
    expect(find.textContaining('4 pours'), findsOneWidget);
  });

  testWidgets('the library sheet clones a built-in into the list', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: BrewListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Brew Library'));
    await tester.pumpAndSettle();
    // addFromTemplate writes to Hive, which is real disk IO. The tap that
    // triggers the write and a short settling delay both have to run inside
    // the same runAsync call so the write starts and lands in the real zone
    // — starting it from a plain tap outside runAsync leaves its completion
    // dangling in the fake-async test zone and hangs teardown.
    await tester.runAsync(() async {
      await tester.tap(find.text('Chemex').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    // addFromTemplate's success snackbar schedules its own auto-dismiss timer,
    // which pumpAndSettle won't wait out on its own; flush it so it doesn't
    // leak past the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(
      Get.find<BrewController>().recipes.map((r) => r.name),
      contains('Chemex'),
    );
  });
}
