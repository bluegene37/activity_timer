// Gene - Nov, 06, 2026: Unit tests for active session persistence and restoration across background termination.

import 'dart:io';

import 'package:activity_timer/controllers/activity_run_controller.dart';
import 'package:activity_timer/hive_registrar.g.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
// Gene - Nov, 06, 2026: Added interval timer model and service imports.
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/services/activity_session_service.dart';
import 'package:activity_timer/services/alarm_scheduler.dart';
import 'package:activity_timer/services/cue_player.dart';
import 'package:activity_timer/services/database_service.dart';
import 'package:activity_timer/services/interval_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeCuePlayer implements CuePlayer {
  @override
  Future<void> playAlarm(AlarmSound sound) async {}

  @override
  Future<void> playCompletion() async {}

  @override
  Future<void> playStart() async {}

  @override
  Future<void> dispose() async {}
}

class _RecordingAlarmScheduler implements AlarmScheduler {
  final List<List<ScheduledAlarm>> scheduledBatches = [];
  int cancelCount = 0;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> schedule(List<ScheduledAlarm> alarms) async {
    scheduledBatches.add(List.from(alarms));
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );

    tempDir = await Directory.systemTemp.createTemp('session_restoration_test');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    db = DatabaseService();
    await db.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  tearDown(() async {
    ActivitySessionService().clear();
    await db.clearActiveActivitySession();
  });

  TimerSequence createTestSequence({
    String id = 'test-seq-1',
    String name = 'HIIT Routine',
    int prep = 5,
    bool loop = false,
  }) => TimerSequence(
    id: id,
    name: name,
    preparationSeconds: prep,
    defaultLoopEnabled: loop,
    timers: [
      ActivityTimer(
        name: 'Work Step',
        durationInSeconds: 30,
        phase: IntervalPhase.work,
      ),
      ActivityTimer(
        name: 'Rest Step',
        durationInSeconds: 15,
        phase: IntervalPhase.rest,
      ),
    ],
  );

  test('restores session when still within the current step', () async {
    final sequence = createTestSequence();
    await db.createActivitySequence(sequence);

    final startTime = DateTime(2026, 11, 6, 12, 0, 0);
    final deadline = startTime.add(const Duration(seconds: 30));

    // Simulate saved state: Work step running with deadline 12:00:30
    await db.saveActiveActivitySession({
      'sequenceId': sequence.id,
      'currentIndex': 0,
      'isPreparing': false,
      'deadlineMs': deadline.millisecondsSinceEpoch,
      'remainingMs': 30000,
      'isRunning': true,
      'loopEnabled': false,
      'loopCount': 0,
      'lastUpdatedMs': startTime.millisecondsSinceEpoch,
    });

    final checkTime = DateTime(2026, 11, 6, 12, 0, 10); // 10s elapsed
    final scheduler = _RecordingAlarmScheduler();

    final restored = await ActivitySessionService().restoreSessionIfActive(
      databaseService: db,
      cuePlayer: _FakeCuePlayer(),
      scheduler: scheduler,
      clock: () => checkTime,
    );

    expect(restored, isNotNull);
    expect(restored!.currentIndex.value, 0);
    expect(restored.isPreparing.value, isFalse);
    expect(restored.isRunning.value, isTrue);
    expect(restored.remainingMs.value, 20000); // 20s remaining
    expect(ActivitySessionService().hasSessionInProgress, isTrue);

    restored.onClose();
  });

  test('advances to next step with overshoot when boundary passed in background', () async {
    final sequence = createTestSequence();
    await db.createActivitySequence(sequence);

    final startTime = DateTime(2026, 11, 6, 12, 0, 0);
    final deadline = startTime.add(const Duration(seconds: 30));

    // Saved at Step 0 (30s)
    await db.saveActiveActivitySession({
      'sequenceId': sequence.id,
      'currentIndex': 0,
      'isPreparing': false,
      'deadlineMs': deadline.millisecondsSinceEpoch,
      'remainingMs': 30000,
      'isRunning': true,
      'loopEnabled': false,
      'loopCount': 0,
      'lastUpdatedMs': startTime.millisecondsSinceEpoch,
    });

    // Reopen 5 seconds into Step 1 (Rest: 15s) -> 35s since start
    final checkTime = DateTime(2026, 11, 6, 12, 0, 35);
    final scheduler = _RecordingAlarmScheduler();

    final restored = await ActivitySessionService().restoreSessionIfActive(
      databaseService: db,
      cuePlayer: _FakeCuePlayer(),
      scheduler: scheduler,
      clock: () => checkTime,
    );

    expect(restored, isNotNull);
    expect(restored!.currentIndex.value, 1); // Rest Step
    expect(restored.isPreparing.value, isFalse);
    expect(restored.isRunning.value, isTrue);
    expect(restored.remainingMs.value, 10000); // 15s - 5s = 10s left
    expect(ActivitySessionService().hasSessionInProgress, isTrue);

    restored.onClose();
  });

  test('clears session if total duration passed and non-looping', () async {
    final sequence = createTestSequence();
    await db.createActivitySequence(sequence);

    final startTime = DateTime(2026, 11, 6, 12, 0, 0);
    final deadline = startTime.add(const Duration(seconds: 30));

    await db.saveActiveActivitySession({
      'sequenceId': sequence.id,
      'currentIndex': 0,
      'isPreparing': false,
      'deadlineMs': deadline.millisecondsSinceEpoch,
      'remainingMs': 30000,
      'isRunning': true,
      'loopEnabled': false,
      'loopCount': 0,
      'lastUpdatedMs': startTime.millisecondsSinceEpoch,
    });

    // Reopen 60s later -> past Step 0 (30s) + Step 1 (15s)
    final checkTime = DateTime(2026, 11, 6, 12, 1, 0);
    final scheduler = _RecordingAlarmScheduler();

    final restored = await ActivitySessionService().restoreSessionIfActive(
      databaseService: db,
      cuePlayer: _FakeCuePlayer(),
      scheduler: scheduler,
      clock: () => checkTime,
    );

    expect(restored, isNull);
    expect(ActivitySessionService().hasSessionInProgress, isFalse);
    expect(await db.getActiveActivitySession(), isNull);
  });

  test('restores paused session in paused state', () async {
    final sequence = createTestSequence();
    await db.createActivitySequence(sequence);

    await db.saveActiveActivitySession({
      'sequenceId': sequence.id,
      'currentIndex': 1,
      'isPreparing': false,
      'deadlineMs': null,
      'remainingMs': 8000,
      'isRunning': false,
      'loopEnabled': false,
      'loopCount': 0,
      'lastUpdatedMs': DateTime.now().millisecondsSinceEpoch,
    });

    final scheduler = _RecordingAlarmScheduler();

    final restored = await ActivitySessionService().restoreSessionIfActive(
      databaseService: db,
      cuePlayer: _FakeCuePlayer(),
      scheduler: scheduler,
    );

    expect(restored, isNotNull);
    expect(restored!.currentIndex.value, 1);
    expect(restored.isRunning.value, isFalse);
    expect(restored.remainingMs.value, 8000);
    expect(ActivitySessionService().hasSessionInProgress, isTrue);

    restored.onClose();
  });

  // Gene - Nov, 06, 2026: Added interval session restoration test.
  test('restores active interval timer session', () async {
    final now = DateTime.now();
    final interval = IntervalTimer(
      id: 'test-interval-1',
      name: 'Workday Stretch',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 4)),
      intervalValue: 1,
      intervalType: IntervalType.hour,
    );
    await db.createIntervalTimer(interval);

    await db.saveActiveIntervalSession({
      'timerId': interval.id,
      'startedAtMs': now.millisecondsSinceEpoch,
    });

    final restored = await IntervalSessionService().restoreSessionIfActive(
      databaseService: db,
      cuePlayer: _FakeCuePlayer(),
    );

    expect(restored, isNotNull);
    expect(restored!.timer.id, interval.id);
    expect(IntervalSessionService().hasSessionInProgress, isTrue);

    IntervalSessionService().clear();
  });

  // Gene - Nov, 06, 2026: Verifies ScheduledAlarm contains deep-linking payload.
  test('pending alarms include activity payload for notification routing', () {
    final sequence = createTestSequence();
    final controller = ActivityRunController(
      sequence: sequence,
      cuePlayer: _FakeCuePlayer(),
      scheduler: _RecordingAlarmScheduler(),
    );
    controller.onInit();

    final alarms = controller.pendingAlarms();
    expect(alarms, isNotEmpty);
    for (final alarm in alarms) {
      expect(alarm.payload, equals('activity:${sequence.id}'));
    }

    controller.onClose();
  });

  // Gene - Nov, 06, 2026: Verifies handlePayload handles null and unknown payloads safely without crashing.
  test('handlePayload handles null and unknown payloads safely', () {
    expect(() => LocalNotificationAlarmScheduler.handlePayload(null), returnsNormally);
    expect(() => LocalNotificationAlarmScheduler.handlePayload('unknown_payload'), returnsNormally);
  });
}
