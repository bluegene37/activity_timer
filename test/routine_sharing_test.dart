import 'package:activity_timer/controllers/activity_list_controller.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routine Sharing & Duplication tests', () {
    test('exports and imports TimerSequence to and from JSON', () {
      final original = TimerSequence(
        name: 'Boxing Sparring Routine',
        description: '3 Rounds with corner rest',
        category: 'fitness',
        preparationSeconds: 5,
        defaultLoopEnabled: false,
        timers: [
          ActivityTimer(name: 'Round 1', durationInSeconds: 180, phase: IntervalPhase.work),
          ActivityTimer(name: 'Corner Rest', durationInSeconds: 60, phase: IntervalPhase.rest),
          ActivityTimer(name: 'Round 2', durationInSeconds: 180, phase: IntervalPhase.work),
        ],
      );

      final jsonStr = ActivityListController.sequenceToJson(original);
      expect(jsonStr.contains('Boxing Sparring Routine'), true);
      expect(jsonStr.contains('fitness'), true);

      final imported = ActivityListController.sequenceFromJson(jsonStr);
      expect(imported, isNotNull);
      expect(imported!.name, 'Boxing Sparring Routine');
      expect(imported.description, '3 Rounds with corner rest');
      expect(imported.category, 'fitness');
      expect(imported.preparationSeconds, 5);
      expect(imported.timers.length, 3);
      expect(imported.timers[0].name, 'Round 1');
      expect(imported.timers[0].phase, IntervalPhase.work);
      expect(imported.timers[1].phase, IntervalPhase.rest);
    });

    test('sequenceFromJson returns null on invalid JSON', () {
      expect(ActivityListController.sequenceFromJson('invalid json string'), isNull);
      expect(ActivityListController.sequenceFromJson('{}'), isNotNull); // Empty object with fallbacks
    });
  });
}
