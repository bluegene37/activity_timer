import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseService Preset Templates tests', () {
    test(
      'provides built-in preset routine templates with categories and phases',
      () {
        final databaseService = DatabaseService();
        final allPresets = databaseService.getPresetTemplates();

        expect(allPresets.isNotEmpty, true);
        expect(allPresets.length, greaterThanOrEqualTo(8));

        // Test fitness presets
        final fitnessPresets = databaseService.getPresetTemplates(
          category: 'fitness',
        );
        expect(fitnessPresets.isNotEmpty, true);
        expect(fitnessPresets.every((p) => p.category == 'fitness'), true);

        final tabata = fitnessPresets.firstWhere(
          (p) => p.name.contains('Tabata'),
        );
        expect(tabata.timers.length, 16); // 8 rounds of work + rest
        expect(tabata.timers.any((t) => t.phase == IntervalPhase.work), true);
        expect(tabata.timers.any((t) => t.phase == IntervalPhase.rest), true);
        expect(tabata.totalDuration, 240); // 4 minutes

        final emom = fitnessPresets.firstWhere((p) => p.name.contains('EMOM'));
        expect(emom.timers.length, 20); // 10 rounds of work + rest
        expect(emom.totalDuration, 600); // 10 minutes

        final boxing = fitnessPresets.firstWhere(
          (p) => p.name.contains('Boxing'),
        );
        expect(boxing.timers.length, 6);
        expect(
          boxing.timers.any((t) => t.phase == IntervalPhase.cooldown),
          true,
        );

        // Test work presets
        final workPresets = databaseService.getPresetTemplates(
          category: 'work',
        );
        expect(workPresets.isNotEmpty, true);
        expect(workPresets.every((p) => p.category == 'work'), true);

        final pomodoro = workPresets.firstWhere(
          (p) => p.name.contains('Pomodoro'),
        );
        expect(
          pomodoro.timers.length,
          8,
        ); // 4 blocks + 3 short breaks + 1 long break
        expect(
          pomodoro.totalDuration,
          7800,
        ); // 4*25m + 3*5m + 15m = 130 min = 7800s

        final standHydrate = workPresets.firstWhere(
          (p) => p.name.contains('Stand & Hydrate'),
        );
        expect(standHydrate.totalDuration, 3600); // 1 hour loop
        expect(standHydrate.defaultLoopEnabled, true);

        final eyeStrain = workPresets.firstWhere(
          (p) => p.name.contains('20-20-20'),
        );
        expect(eyeStrain.totalDuration, 1220);
      },
    );
  });
}
