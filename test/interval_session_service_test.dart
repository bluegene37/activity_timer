import 'dart:io';

import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/services/brew_cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _SilentCuePlayer implements BrewCuePlayer {
  @override
  Future<void> playStepEnd(AlarmSound sound) async {}

  @override
  Future<void> playCompleted() async {}

  @override
  Future<void> dispose() async {}
}

IntervalTimer timer({String name = 'Stretch'}) {
  final now = DateTime.now();
  return IntervalTimer(
    name: name,
    startTime: now.subtract(const Duration(minutes: 1)),
    endTime: now.add(const Duration(minutes: 10)),
    intervalValue: 1,
    intervalType: IntervalType.minute,
  );
}

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

    tempDir = await Directory.systemTemp.createTemp('interval_session_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    await DatabaseService().init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  final session = IntervalSessionService();

  tearDown(session.clear);

  test('obtain creates a running controller as the active session', () {
    final t = timer();
    final controller = session.obtain(t, cuePlayer: _SilentCuePlayer());

    expect(session.active.value, same(controller));
    expect(controller.timer.id, t.id);
    expect(
      controller.isRunning.value,
      isTrue,
      reason: 'interval sessions start the moment they are opened',
    );
  });

  test('obtain returns the SAME controller for the same timer', () {
    final t = timer();
    final first = session.obtain(t, cuePlayer: _SilentCuePlayer());
    final second = session.obtain(t, cuePlayer: _SilentCuePlayer());

    expect(
      second,
      same(first),
      reason: 'reopening the screen must resume, not restart',
    );
  });

  test('obtain for a different timer replaces the session', () {
    final first = session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    final second = session.obtain(
      timer(name: 'Water'),
      cuePlayer: _SilentCuePlayer(),
    );

    expect(second, isNot(same(first)));
    expect(session.active.value, same(second));
  });

  test('clear closes the session', () {
    session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    session.clear();

    expect(session.active.value, isNull);
  });

  test('hasSessionInProgress is false only when done or absent', () {
    expect(session.hasSessionInProgress, isFalse, reason: 'no session at all');

    final controller = session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    expect(session.hasSessionInProgress, isTrue);

    // Skip through the whole schedule to completion.
    while (!controller.isCompleted.value) {
      controller.skipToNext();
    }
    expect(
      session.hasSessionInProgress,
      isFalse,
      reason: 'a completed schedule has nothing left to float',
    );
  });

  test('releaseIfIdle keeps a running session and drops a completed one', () {
    final controller = session.obtain(timer(), cuePlayer: _SilentCuePlayer());
    session.releaseIfIdle();
    expect(
      session.active.value,
      same(controller),
      reason: 'running schedule survives the screen being popped',
    );

    while (!controller.isCompleted.value) {
      controller.skipToNext();
    }
    session.releaseIfIdle();
    expect(session.active.value, isNull, reason: 'completed -> no floater');
  });
}
