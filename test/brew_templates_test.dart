import 'package:activity_timer/models/brew_recipe.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = DatabaseService();

  test('ships five built-in recipes', () {
    expect(db.getBrewTemplates().length, 5);
    expect(
      db.getBrewTemplates().map((r) => r.name),
      containsAll(<String>[
        'Hoffmann V60',
        'Kasuya 4:6',
        'Chemex',
        'Kalita Wave',
        'AeroPress',
      ]),
    );
  });

  test('filters by method', () {
    final v60 = db.getBrewTemplates(method: BrewMethod.v60);
    expect(v60, isNotEmpty);
    expect(v60.every((r) => r.method == BrewMethod.v60), isTrue);
  });

  test('every built-in is valid', () {
    for (final recipe in db.getBrewTemplates()) {
      expect(
        recipe.validationErrors(),
        isEmpty,
        reason: '${recipe.name} must satisfy every recipe invariant',
      );
    }
  });

  test('Hoffmann V60 pours 60g, 300g, 500g at 30g of coffee', () {
    final recipe = db.getBrewTemplates().firstWhere(
      (r) => r.name == 'Hoffmann V60',
    );
    expect(recipe.totalWaterGrams, 500);
    expect(
      [
        for (var i = 0; i < recipe.steps.length; i++) recipe.targetGramsAt(i),
      ].whereType<int>().toList(),
      [60, 300, 500],
    );
    expect(recipe.totalSeconds, 225);
  });

  test('Kasuya 4:6 pours five even fifths', () {
    final recipe = db.getBrewTemplates().firstWhere(
      (r) => r.name == 'Kasuya 4:6',
    );
    expect(recipe.totalWaterGrams, 300);
    expect(
      [
        for (var i = 0; i < recipe.steps.length; i++) recipe.targetGramsAt(i),
      ].whereType<int>().toList(),
      [60, 120, 180, 240, 300],
    );
  });
}
