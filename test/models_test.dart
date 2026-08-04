import 'package:flutter_test/flutter_test.dart';
import 'package:activity_timer/models/activity_timer.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/session_history.dart';

void main() {
  group('ActivityTimer tests', () {
    test('creates ActivityTimer with default values', () {
      final timer = ActivityTimer(
        name: 'Work Step',
        durationInSeconds: 1500,
      );

      expect(timer.name, 'Work Step');
      expect(timer.durationInSeconds, 1500);
      expect(timer.alarmSoundName, isNull);
    });

    test('custom alarm sound setting and getter', () {
      final timer = ActivityTimer(
        name: 'Sprint Rest',
        durationInSeconds: 300,
        alarmSoundName: 'digital',
      );

      expect(timer.alarmSound, AlarmSound.digital);
      
      timer.alarmSoundName = AlarmSound.chime.name;
      expect(timer.alarmSound, AlarmSound.chime);
      expect(timer.alarmSoundName, 'chime');
    });
  });

  group('TimerSequence tests', () {
    test('calculates total duration correctly', () {
      final sequence = TimerSequence(
        name: 'Pomodoro Routine',
        timers: [
          ActivityTimer(name: 'Focus 1', durationInSeconds: 1500),
          ActivityTimer(name: 'Break 1', durationInSeconds: 300),
          ActivityTimer(name: 'Focus 2', durationInSeconds: 1500),
        ],
      );

      expect(sequence.totalDuration, 3300);
      expect(sequence.timers.length, 3);
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
    test('instantiates session history model', () {
      final now = DateTime.now();
      final history = SessionHistory(
        title: 'Tabata Workout',
        totalDurationInSeconds: 240,
        itemCount: 8,
        loopCount: 1,
        sessionType: 'sequence',
        completedAt: now,
      );

      expect(history.title, 'Tabata Workout');
      expect(history.totalDurationInSeconds, 240);
      expect(history.itemCount, 8);
      expect(history.sessionType, 'sequence');
      expect(history.completedAt, now);
    });
  });
}
