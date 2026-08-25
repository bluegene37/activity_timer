import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('brew_db_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  BrewRecipe sample() => BrewRecipe(
    name: 'Morning V60',
    method: BrewMethod.v60,
    doseGrams: 18,
    ratio: 16,
    steps: [
      BrewStep(
        name: 'Bloom',
        seconds: 45,
        pourToFraction: 0.12,
        pourSeconds: 10,
      ),
      BrewStep(
        name: 'Main pour',
        seconds: 60,
        pourToFraction: 1,
        pourSeconds: 30,
      ),
    ],
  );

  test('create, read, update, and delete a brew recipe', () async {
    final db = DatabaseService();
    final recipe = sample();

    final id = await db.createBrewRecipe(recipe);
    expect(id, recipe.id);
    expect(await db.getBrewRecipe(id), isNotNull);
    expect((await db.getAllBrewRecipes()).map((r) => r.id), contains(id));

    final stored = (await db.getBrewRecipe(id))!;
    expect(stored.steps.length, 2);
    expect(stored.method, BrewMethod.v60);
    expect(stored.targetGramsAt(1), 288, reason: '18g x 16 = 288g');

    final before = stored.updatedAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    stored.doseGrams = 20;
    await db.updateBrewRecipe(stored);
    final reloaded = (await db.getBrewRecipe(id))!;
    expect(reloaded.totalWaterGrams, 320);
    expect(reloaded.updatedAt.isAfter(before), isTrue);

    await db.deleteBrewRecipe(id);
    expect(await db.getBrewRecipe(id), isNull);
  });
}
