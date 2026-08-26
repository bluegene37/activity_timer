import 'dart:io';

import 'package:activity_timer/controllers/activity_list_controller.dart';
import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _SilentCuePlayer implements CuePlayer {
  @override
  Future<void> playAlarm(AlarmSound sound) async {}

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async {}
}

/// The loop toggle is a saved preference, not a per-run switch. These tests
/// use the real database rather than a fake saver, because the interesting
/// question is not "was save called" but "is the value there next time".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp('loop_persistence_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    ActivitySessionService().clear();
    for (final s in await DatabaseService().getAllActivitySequences()) {
      await DatabaseService().deleteActivitySequence(s.id);
    }
  });

  TimerSequence routine() => TimerSequence(
    name: 'Gym',
    preparationSeconds: 0,
    timers: [
      ActivityTimer(
        name: 'Squats',
        durationInSeconds: 600,
        phase: IntervalPhase.work,
      ),
    ],
  );

  Future<TimerSequence> reloadFromDb(String id) async {
    final all = await DatabaseService().getAllActivitySequences();
    return all.singleWhere((s) => s.id == id);
  }

  test('toggling loop writes it to the database', () async {
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);
    expect(seq.defaultLoopEnabled, isFalse);

    final controller = ActivityRunController(
      sequence: seq,
      cuePlayer: _SilentCuePlayer(),
      scheduler: NoopAlarmScheduler(),
      historyLogger: (_) async {},
    )..onInit();

    controller.toggleLoop();
    // The write is fire-and-forget; let it land.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    controller.onClose();

    final stored = await reloadFromDb(seq.id);
    expect(
      stored.defaultLoopEnabled,
      isTrue,
      reason: 'the routine must remember it loops',
    );
  });

  test('a routine reopened after a restart comes back looping', () async {
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);

    final first = ActivityRunController(
      sequence: seq,
      cuePlayer: _SilentCuePlayer(),
      scheduler: NoopAlarmScheduler(),
      historyLogger: (_) async {},
    )..onInit();
    first.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    first.onClose();

    // A restart: nothing in memory survives, so the routine is read back
    // out of the database exactly as the list screen would.
    final reloaded = await reloadFromDb(seq.id);
    final second = ActivityRunController(
      sequence: reloaded,
      cuePlayer: _SilentCuePlayer(),
      scheduler: NoopAlarmScheduler(),
      historyLogger: (_) async {},
    )..onInit();

    expect(
      second.loopEnabled.value,
      isTrue,
      reason: 'the toggle must survive a restart, not just the session',
    );
    second.onClose();
  });

  test('toggling it back off persists too', () async {
    final seq = routine()..defaultLoopEnabled = true;
    await DatabaseService().createActivitySequence(seq);

    final controller = ActivityRunController(
      sequence: seq,
      cuePlayer: _SilentCuePlayer(),
      scheduler: NoopAlarmScheduler(),
      historyLogger: (_) async {},
    )..onInit();
    expect(controller.loopEnabled.value, isTrue, reason: 'starts from saved');

    controller.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    controller.onClose();

    final stored = await reloadFromDb(seq.id);
    expect(stored.defaultLoopEnabled, isFalse);
  });

  test('the session service path persists it too', () async {
    // The production route: the screen borrows its controller from the
    // service, which builds one with the real database saver.
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);

    final controller = ActivitySessionService().obtain(
      seq,
      cuePlayer: _SilentCuePlayer(),
    );
    controller.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    ActivitySessionService().clear();

    final stored = await reloadFromDb(seq.id);
    expect(
      stored.defaultLoopEnabled,
      isTrue,
      reason: 'the real screen path must save, not just the injected one',
    );
  });

  test('the list still shows it looping after a reload from disk', () async {
    // The full flow: the list holds the routine, the run screen toggles it,
    // and a later reload (a restart, or the list refreshing) must agree.
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);

    final fromList = (await DatabaseService().getAllActivitySequences())
        .singleWhere((s) => s.id == seq.id);

    final controller = ActivitySessionService().obtain(
      fromList,
      cuePlayer: _SilentCuePlayer(),
    );
    controller.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    ActivitySessionService().clear();

    // What the list would hold in memory after the toggle.
    expect(
      fromList.defaultLoopEnabled,
      isTrue,
      reason: 'the in-memory copy the list holds must reflect the toggle',
    );

    // And what a fresh load off disk sees.
    final reloaded = await reloadFromDb(seq.id);
    expect(reloaded.defaultLoopEnabled, isTrue);
  });

  test('toggling loop in the list reaches a minimized run session', () async {
    // The flow that used to lose the setting: a routine is minimized (so a
    // session still holds it), the loop is toggled from the list, and the
    // routine is reopened. Before the fix the list swapped in a copy, so
    // the live session kept the old flag and re-saved it on its next write.
    final seq = routine();
    await DatabaseService().createActivitySequence(seq);

    final list = ActivityListController();
    await list.loadSequences();
    final index = list.sequences.indexWhere((s) => s.id == seq.id);
    expect(index, isNot(-1));

    // The routine is opened and minimized: the session keeps this instance.
    final session = ActivitySessionService();
    final controller = session.obtain(
      list.sequences[index],
      cuePlayer: _SilentCuePlayer(),
    );
    expect(controller.loopEnabled.value, isFalse);

    // Now loop it from the list while the session is still alive.
    await list.toggleDefaultLoop(index);

    expect(
      controller.sequence.defaultLoopEnabled,
      isTrue,
      reason: 'the live session must see the change, not a stale copy',
    );
    expect(list.sequences[index].defaultLoopEnabled, isTrue);
    expect((await reloadFromDb(seq.id)).defaultLoopEnabled, isTrue);

    // And the session's own save must not write the old value back.
    controller.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await reloadFromDb(seq.id)).defaultLoopEnabled, isFalse);

    controller.toggleLoop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      (await reloadFromDb(seq.id)).defaultLoopEnabled,
      isTrue,
      reason: 'toggling from either place must agree on one stored value',
    );

    session.clear();
  });
}
