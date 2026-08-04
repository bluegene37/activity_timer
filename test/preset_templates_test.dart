import 'package:flutter_test/flutter_test.dart';
import 'package:activity_timer/services/database_service.dart';

void main() {
  group('DatabaseService Preset Templates tests', () {
    test('provides built-in preset routine templates', () {
      final databaseService = DatabaseService();
      final presets = databaseService.getPresetTemplates();

      expect(presets.isNotEmpty, true);
      expect(presets.length, greaterThanOrEqualTo(4));

      final pomodoro = presets.firstWhere((p) => p.name.contains('Pomodoro'));
      expect(pomodoro.timers.length, 4);
      expect(pomodoro.totalDuration, 4200); // 25 + 5 + 25 + 15 = 70 mins = 4200s

      final tabata = presets.firstWhere((p) => p.name.contains('Tabata'));
      expect(tabata.timers.length, 2); // 20s Work, 10s Rest with loop enabled
      expect(tabata.defaultLoopEnabled, true);
      expect(tabata.totalDuration, 30); // 30s per loop round
    });
  });
}
