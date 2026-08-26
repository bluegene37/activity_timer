import 'dart:io';

import 'package:activity_timer/controllers/timer_list_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// The routine detail screen has its own loop toggle, separate from the run
/// screen's. It goes through TimerListController.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_list_loop_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    for (final s in await DatabaseService().getAllActivitySequences()) {
      await DatabaseService().deleteActivitySequence(s.id);
    }
  });

  TimerSequence routine({bool loop = false}) => TimerSequence(
    name: 'Gym',
    defaultLoopEnabled: loop,
    timers: [
      ActivityTimer(
        name: 'Squats',
        durationInSeconds: 60,
        phase: IntervalPhase.work,
      ),
    ],
  );

  Future<bool> storedLoop(String id) async {
    final all = await DatabaseService().getAllActivitySequences();
    return all.singleWhere((s) => s.id == id).defaultLoopEnabled;
  }

  test('turning loop ON from the detail screen saves', () async {
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);

    final controller = TimerListController()..load(seq);
    await controller.toggleDefaultLoop();

    expect(controller.sequence.value.defaultLoopEnabled, isTrue);
    expect(await storedLoop(seq.id), isTrue);
  });

  test('turning loop OFF from the detail screen saves', () async {
    final seq = routine(loop: true);
    await DatabaseService().createActivitySequence(seq);

    final controller = TimerListController()..load(seq);
    expect(controller.sequence.value.defaultLoopEnabled, isTrue);

    await controller.toggleDefaultLoop();

    expect(
      controller.sequence.value.defaultLoopEnabled,
      isFalse,
      reason: 'the toggle must be able to turn looping off',
    );
    expect(
      await storedLoop(seq.id),
      isFalse,
      reason: 'and off must be what is stored',
    );
  });

  test('toggling twice returns to where it started', () async {
    final seq = routine(loop: true);
    await DatabaseService().createActivitySequence(seq);

    final controller = TimerListController()..load(seq);
    await controller.toggleDefaultLoop();
    await controller.toggleDefaultLoop();

    expect(controller.sequence.value.defaultLoopEnabled, isTrue);
    expect(await storedLoop(seq.id), isTrue);
  });

  test('the routine keeps its steps through a loop toggle', () async {
    // copyWith rebuilds the step list; the routine must not lose or
    // duplicate steps just because a flag changed.
    final seq = routine(loop: true);
    await DatabaseService().createActivitySequence(seq);
    final originalStepIds = seq.timers.map((t) => t.id).toList();

    final controller = TimerListController()..load(seq);
    await controller.toggleDefaultLoop();

    final all = await DatabaseService().getAllActivitySequences();
    final stored = all.singleWhere((s) => s.id == seq.id);
    expect(stored.timers.map((t) => t.id), originalStepIds);
  });

  test('reopening the routine does not revert the loop setting', () async {
    // What the user sees: the list holds one instance of the routine and
    // hands it to the detail screen on every open. If the toggle swaps in a
    // copy instead of changing that instance, the list keeps the old flag —
    // so the next open loads it back and the setting appears to never
    // change.
    final fromList = routine(loop: true);
    await DatabaseService().createActivitySequence(fromList);

    final controller = TimerListController()..load(fromList);
    await controller.toggleDefaultLoop();
    expect(controller.sequence.value.defaultLoopEnabled, isFalse);

    // Reopen: the screen loads the list's instance into the same
    // (lazy-singleton) controller.
    controller.load(fromList);

    expect(
      controller.sequence.value.defaultLoopEnabled,
      isFalse,
      reason: 'reopening must not resurrect the old setting',
    );
    expect(await storedLoop(fromList.id), isFalse);
  });

  test('the prep countdown also survives reopening', () async {
    // Same shape as the loop toggle: it used to save a copy, leaving the
    // list on the old value.
    final fromList = routine();
    await DatabaseService().createActivitySequence(fromList);

    final controller = TimerListController()..load(fromList);
    await controller.updatePreparationSeconds(12);

    expect(controller.sequence.value.preparationSeconds, 12);
    expect(fromList.preparationSeconds, 12, reason: 'the list sees it too');

    controller.load(fromList);
    expect(controller.sequence.value.preparationSeconds, 12);

    final all = await DatabaseService().getAllActivitySequences();
    expect(all.singleWhere((s) => s.id == fromList.id).preparationSeconds, 12);
  });

  test('adding a step keeps the list and the screen in agreement', () async {
    final fromList = routine();
    await DatabaseService().createActivitySequence(fromList);

    final controller = TimerListController()..load(fromList);
    final added = ActivityTimer(
      name: 'Plank',
      durationInSeconds: 30,
      phase: IntervalPhase.work,
    );
    await DatabaseService().addTimerToSequence(fromList.id, added);
    controller.sequence.value.timers = [
      ...controller.sequence.value.timers,
      added,
    ];

    expect(
      fromList.timers.map((t) => t.name),
      contains('Plank'),
      reason: 'the routine the list holds must gain the step too',
    );
  });
}
