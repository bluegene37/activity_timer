import 'package:activity_timer/models/alarm_sound.dart';
import 'package:activity_timer/models/interval_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntervalTimer tests for Workplace & Activity scenarios', () {
    test('calculates exact alarm times for hourly workplace check-ins', () {
      final startTime = DateTime(2026, 8, 23, 9, 0); // 9:00 AM
      final endTime = DateTime(2026, 8, 23, 17, 0); // 5:00 PM (8 hours)

      final timer = IntervalTimer(
        name: 'Hourly Boss Check-in',
        startTime: startTime,
        endTime: endTime,
        intervalValue: 1,
        intervalType: IntervalType.hour,
        alarmSoundName: AlarmSound.bell.name,
      );

      // Gene - Oct, 06, 2026: Added assertion for shortIntervalString on 1 hour interval timer.
      expect(timer.intervalString, 'Every hour');
      expect(timer.shortIntervalString, 'Every 1 hr');
      expect(timer.totalAlarms, 9); // 9:00, 10:00, ..., 17:00 (9 alarms total)

      final alarmTimes = timer.getAllAlarmTimes();
      expect(alarmTimes.length, 9);
      expect(alarmTimes[0], DateTime(2026, 8, 23, 9, 0));
      expect(alarmTimes[1], DateTime(2026, 8, 23, 10, 0));
      expect(alarmTimes.last, DateTime(2026, 8, 23, 17, 0));

      // Test next alarm lookup during the day
      final midDay = DateTime(2026, 8, 23, 10, 15);
      final nextAlarm = timer.getNextAlarmTime(midDay);
      expect(nextAlarm, DateTime(2026, 8, 23, 11, 0));
    });

    test('calculates exact alarm times for bi-hourly reporting', () {
      final startTime = DateTime(2026, 8, 23, 9, 0);
      final endTime = DateTime(2026, 8, 23, 17, 0);

      final timer = IntervalTimer(
        name: 'Bi-Hourly Status Report',
        startTime: startTime,
        endTime: endTime,
        intervalValue: 2,
        intervalType: IntervalType.hour,
      );

      // Gene - Oct, 06, 2026: Added assertion for shortIntervalString on 2 hour interval timer.
      expect(timer.intervalString, 'Every 2 hours');
      expect(timer.shortIntervalString, 'Every 2 hr');
      expect(timer.totalAlarms, 5); // 9:00, 11:00, 13:00, 15:00, 17:00

      final alarmTimes = timer.getAllAlarmTimes();
      expect(alarmTimes.length, 5);
      expect(alarmTimes[0], DateTime(2026, 8, 23, 9, 0));
      expect(alarmTimes[1], DateTime(2026, 8, 23, 11, 0));
      expect(alarmTimes[2], DateTime(2026, 8, 23, 13, 0));
      expect(alarmTimes[3], DateTime(2026, 8, 23, 15, 0));
      expect(alarmTimes[4], DateTime(2026, 8, 23, 17, 0));
    });

    test(
      'calculates exact alarm times for 30-min hydration / posture check',
      () {
        final startTime = DateTime(2026, 8, 23, 9, 0);
        final endTime = DateTime(2026, 8, 23, 12, 0); // 3 hours

        final timer = IntervalTimer(
          name: 'Stand & Hydrate',
          startTime: startTime,
          endTime: endTime,
          intervalValue: 30,
          intervalType: IntervalType.minute,
        );

        // Gene - Oct, 06, 2026: Added assertions for shortIntervalString on 30 min and 15 min interval timers.
        expect(timer.intervalString, 'Every 30 minutes');
        expect(timer.shortIntervalString, 'Every 30 min');
        expect(
          timer.totalAlarms,
          7,
        ); // 9:00, 9:30, 10:00, 10:30, 11:00, 11:30, 12:00

        final sprintTimer = IntervalTimer(
          name: '15-Min Sprint Drills',
          startTime: startTime,
          endTime: endTime,
          intervalValue: 15,
          intervalType: IntervalType.minute,
        );
        expect(sprintTimer.intervalString, 'Every 15 minutes');
        expect(sprintTimer.shortIntervalString, 'Every 15 min');
      },
    );
  });
}
