import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_phase.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/session_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntervalPhase tests', () {
    test('has valid display names and icons', () {
      expect(IntervalPhase.work.displayName, 'Work');
      expect(IntervalPhase.rest.displayName, 'Rest');
      expect(IntervalPhase.prepare.displayName, 'Prepare');
      expect(IntervalPhase.cooldown.displayName, 'Cool Down');
    });

    test('fromString parses correctly with fallback', () {
      expect(IntervalPhase.fromString('work'), IntervalPhase.work);
      expect(IntervalPhase.fromString('REST'), IntervalPhase.rest);
      expect(IntervalPhase.fromString('prepare'), IntervalPhase.prepare);
      expect(IntervalPhase.fromString('cooldown'), IntervalPhase.cooldown);
      expect(IntervalPhase.fromString('unknown'), IntervalPhase.work);
      expect(IntervalPhase.fromString(null), IntervalPhase.work);
    });
  });

  group('ActivityTimer tests', () {
    test('creates ActivityTimer with default values and work phase', () {
      final timer = ActivityTimer(
        name: 'Work Step',
        durationInSeconds: 1500,
      );

      expect(timer.name, 'Work Step');
      expect(timer.durationInSeconds, 1500);
      expect(timer.phase, IntervalPhase.work);
      expect(timer.isWork, true);
      expect(timer.isRest, false);
      expect(timer.alarmSoundName, isNull);
    });

    test('custom alarm sound setting and getter', () {
      final timer = ActivityTimer(
        name: 'Sprint Rest',
        durationInSeconds: 300,
        alarmSoundName: 'digital',
        phase: IntervalPhase.rest,
      );

      expect(timer.alarmSound, AlarmSound.digital);
      expect(timer.isRest, true);
      
      timer.alarmSoundName = AlarmSound.chime.name;
      expect(timer.alarmSound, AlarmSound.chime);
      expect(timer.alarmSoundName, 'chime');
    });

    test('copyWith updates fields including phase', () {
      final timer = ActivityTimer(
        name: 'Sprint',
        durationInSeconds: 30,
        phase: IntervalPhase.work,
      );

      final updated = timer.copyWith(
        name: 'Rest Block',
        durationInSeconds: 15,
        phase: IntervalPhase.rest,
      );

      expect(updated.name, 'Rest Block');
      expect(updated.durationInSeconds, 15);
      expect(updated.phase, IntervalPhase.rest);
      expect(updated.isRest, true);
      expect(updated.id, timer.id);
    });

    test('toJson and fromJson serialize properly', () {
      final timer = ActivityTimer(
        name: 'Warmup',
        durationInSeconds: 60,
        description: 'Light stretch',
        phase: IntervalPhase.prepare,
      );

      final json = timer.toJson();
      final fromJson = ActivityTimer.fromJson(json);

      expect(fromJson.name, 'Warmup');
      expect(fromJson.durationInSeconds, 60);
      expect(fromJson.description, 'Light stretch');
      expect(fromJson.phase, IntervalPhase.prepare);
    });
  });

  group('TimerSequence tests', () {
    test('calculates total duration and supports category/preparationSeconds', () {
      final sequence = TimerSequence(
        name: 'Tabata',
        category: 'fitness',
        preparationSeconds: 10,
        timers: [
          ActivityTimer(name: 'Sprint', durationInSeconds: 20, phase: IntervalPhase.work),
          ActivityTimer(name: 'Rest', durationInSeconds: 10, phase: IntervalPhase.rest),
        ],
      );

      expect(sequence.totalDuration, 30);
      expect(sequence.timers.length, 2);
      expect(sequence.category, 'fitness');
      expect(sequence.preparationSeconds, 10);
    });

    test('toJson and fromJson roundtrip serialization', () {
      final sequence = TimerSequence(
        name: 'Pomodoro',
        category: 'work',
        preparationSeconds: 5,
        timers: [
          ActivityTimer(name: 'Focus', durationInSeconds: 1500, phase: IntervalPhase.work),
          ActivityTimer(name: 'Short Break', durationInSeconds: 300, phase: IntervalPhase.rest),
        ],
      );

      final json = sequence.toJson();
      final fromJson = TimerSequence.fromJson(json);

      expect(fromJson.name, 'Pomodoro');
      expect(fromJson.category, 'work');
      expect(fromJson.preparationSeconds, 5);
      expect(fromJson.timers.length, 2);
      expect(fromJson.timers[0].phase, IntervalPhase.work);
      expect(fromJson.timers[1].phase, IntervalPhase.rest);
    });
  });

  group('IntervalTimer tests', () {
    test('calculates correct alarm count for 1 hour interval over 4 hours', () {
      final start = DateTime(2026, 1, 1, 9, 0);
      final end = DateTime(2026, 1, 1, 13, 0);

      final intervalTimer = IntervalTimer(
        name: 'Hourly Stand Up',
        startTime: start,
        endTime: end,
        intervalValue: 1,
        intervalType: IntervalType.hour,
      );

      expect(intervalTimer.totalAlarms, 5); // 9:00, 10:00, 11:00, 12:00, 13:00
      expect(intervalTimer.getAllAlarmTimes().length, 5);
      expect(intervalTimer.intervalString, 'Every hour');
    });
  });

  group('SessionHistory tests', () {
    test('instantiates session history model with category', () {
      final now = DateTime.now();
      final history = SessionHistory(
        title: 'Tabata Workout',
        totalDurationInSeconds: 240,
        itemCount: 8,
        loopCount: 1,
        sessionType: 'activity',
        category: 'fitness',
        completedAt: now,
      );

      expect(history.title, 'Tabata Workout');
      expect(history.totalDurationInSeconds, 240);
      expect(history.itemCount, 8);
      expect(history.sessionType, 'activity');
      expect(history.category, 'fitness');
      expect(history.completedAt, now);
    });
  });
}
