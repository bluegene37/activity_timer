import 'package:activity_timer/models/brew_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

BrewRecipe kalita({double dose = 20, double ratio = 16}) => BrewRecipe(
  name: 'Kalita Wave',
  method: BrewMethod.kalita,
  doseGrams: dose,
  ratio: ratio,
  steps: [
    BrewStep(
      name: 'Bloom',
      seconds: 30,
      pourToFraction: 0.1875,
      pourSeconds: 10,
      description: 'Wet the bed evenly, then leave it alone.',
    ),
    BrewStep(
      name: 'Second pour',
      seconds: 30,
      pourToFraction: 0.5,
      pourSeconds: 15,
    ),
    BrewStep(
      name: 'Third pour',
      seconds: 30,
      pourToFraction: 0.75,
      pourSeconds: 15,
    ),
    BrewStep(
      name: 'Final pour',
      seconds: 30,
      pourToFraction: 1,
      pourSeconds: 15,
    ),
    BrewStep(name: 'Drawdown', seconds: 60, kind: BrewStepKind.drawdown),
  ],
);

void main() {
  group('BrewRecipe scaling', () {
    test('total water is dose times ratio', () {
      expect(kalita().totalWater, 320);
      expect(kalita().totalWaterGrams, 320);
      expect(kalita(dose: 30).totalWaterGrams, 480);
    });

    test('targets are cumulative whole grams', () {
      final recipe = kalita();
      expect(recipe.targetGramsAt(0), 60);
      expect(recipe.targetGramsAt(1), 160);
      expect(recipe.targetGramsAt(2), 240);
      expect(recipe.targetGramsAt(3), 320);
      expect(recipe.targetGramsAt(4), isNull, reason: 'drawdown pours nothing');
    });

    test('every target rescales with the dose', () {
      final recipe = kalita(dose: 30);
      expect(
        [for (var i = 0; i < 4; i++) recipe.targetGramsAt(i)],
        [90, 240, 360, 480],
      );
    });

    test('the last pour lands exactly on the total', () {
      final recipe = kalita(dose: 17.5, ratio: 16.7); // 292.25 -> 292
      expect(recipe.targetGramsAt(3), recipe.totalWaterGrams);
    });

    test('added grams is the delta from the previous pour', () {
      final recipe = kalita();
      expect(recipe.addedGramsAt(0), 60);
      expect(recipe.addedGramsAt(1), 100);
      expect(recipe.addedGramsAt(3), 80);
      expect(recipe.addedGramsAt(4), isNull);
    });

    test('pour rate is added grams over the pour window', () {
      final recipe = kalita();
      expect(recipe.pourRateAt(0), 6);
      expect(recipe.pourRateAt(1), closeTo(6.67, 0.01));
      expect(recipe.pourRateAt(4), isNull);
    });

    test('totals and counts', () {
      expect(kalita().totalSeconds, 180);
      expect(kalita().pourCount, 4);
    });
  });

  group('BrewRecipe validation', () {
    test('a well-formed recipe has no errors', () {
      expect(kalita().validationErrors(), isEmpty);
    });

    test('rejects a target that goes backwards', () {
      final recipe = kalita();
      recipe.steps[2].pourToFraction = 0.4;
      expect(
        recipe.validationErrors(),
        contains(contains('pours to less water than the step before')),
      );
    });

    test('rejects a pour window longer than its step', () {
      final recipe = kalita();
      recipe.steps[1].pourSeconds = 45;
      expect(
        recipe.validationErrors(),
        contains(contains('pours for longer than the step lasts')),
      );
    });

    test('rejects a pour with no pour window', () {
      final recipe = kalita();
      recipe.steps[1].pourSeconds = null;
      expect(
        recipe.validationErrors(),
        contains(contains('needs a pour time')),
      );
    });

    test('rejects a final pour that stops short of the total', () {
      final recipe = kalita();
      recipe.steps[3].pourToFraction = 0.9;
      expect(
        recipe.validationErrors(),
        contains(contains('last pour must reach the full water total')),
      );
    });

    test('rejects zero-length steps, empty names, and bad dose or ratio', () {
      final recipe = BrewRecipe(
        name: '  ',
        method: BrewMethod.v60,
        doseGrams: 0,
        ratio: 0,
        steps: [
          BrewStep(
            name: 'Bloom',
            seconds: 0,
            pourToFraction: 1,
            pourSeconds: 5,
          ),
        ],
      );
      final errors = recipe.validationErrors();
      expect(errors, contains(contains('Name cannot be empty')));
      expect(errors, contains(contains('Dose must be greater than 0')));
      expect(errors, contains(contains('Ratio must be greater than 0')));
      expect(errors, contains(contains('must be longer than 0s')));
    });
  });

  test('cloneAsNew copies steps and gives a new id', () {
    final original = kalita();
    final copy = original.cloneAsNew();
    expect(copy.id, isNot(original.id));
    expect(copy.steps.length, original.steps.length);
    expect(copy.steps.first, isNot(same(original.steps.first)));
    copy.steps.first.seconds = 99;
    expect(
      original.steps.first.seconds,
      30,
      reason: 'steps must be deep-copied',
    );
  });
}
