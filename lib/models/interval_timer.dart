import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'alarm_sound.dart';

part 'interval_timer.g.dart';

@HiveType(typeId: 4)
enum IntervalType {
  @HiveField(0)
  hour('Hours', 'hour', 'hours', Duration.secondsPerHour),
  @HiveField(1)
  minute('Minutes', 'minute', 'minutes', Duration.secondsPerMinute),
  @HiveField(2)
  second('Seconds', 'second', 'seconds', 1);

  const IntervalType(
    this.displayName,
    this.singularUnit,
    this.pluralUnit,
    this.secondsPerUnit,
  );

  /// Label for pickers and dropdowns, e.g. 'Hours'.
  final String displayName;
  final String singularUnit;
  final String pluralUnit;
  final int secondsPerUnit;

  /// 'hour' for 1, 'hours' otherwise.
  String unitLabel(int value) => value == 1 ? singularUnit : pluralUnit;

  /// Total seconds spanned by [value] units of this type.
  int secondsFor(int value) => value * secondsPerUnit;

  /// Total duration spanned by [value] units of this type.
  Duration durationFor(int value) => Duration(seconds: secondsFor(value));

  /// 'Every hour' for 1, 'Every 3 hours' otherwise.
  String everyLabel(int value) =>
      value == 1 ? 'Every $singularUnit' : 'Every $value $pluralUnit';
}

@HiveType(typeId: 3)
class IntervalTimer extends HiveObject {
  IntervalTimer({
    String? id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.intervalValue,
    required this.intervalType,
    this.isActive = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? alarmSoundName,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       alarmSoundName = alarmSoundName ?? AlarmSound.beep.name;

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime startTime;

  @HiveField(3)
  DateTime endTime;

  @HiveField(4)
  int intervalValue;

  @HiveField(5)
  IntervalType intervalType;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  String alarmSoundName;

  /// Seconds between two consecutive alarms.
  int get intervalInSeconds => intervalType.secondsFor(intervalValue);

  /// Time between two consecutive alarms.
  Duration get interval => intervalType.durationFor(intervalValue);

  AlarmSound get alarmSound => AlarmSound.fromString(alarmSoundName);

  void setAlarmSound(AlarmSound sound) {
    alarmSoundName = sound.name;
  }

  /// Calculate the next alarm time from a given reference time.
  DateTime getNextAlarmTime(DateTime referenceTime) {
    // Before the window opens, the first alarm is the start time itself.
    if (referenceTime.isBefore(startTime)) return startTime;

    // After the window closes there is no next alarm.
    if (referenceTime.isAfter(endTime)) return endTime;

    final elapsed = referenceTime.difference(startTime);
    final passedIntervals = elapsed.inSeconds ~/ intervalInSeconds;
    final nextAlarmTime = startTime.add(
      Duration(seconds: (passedIntervals + 1) * intervalInSeconds),
    );

    return nextAlarmTime.isAfter(endTime) ? endTime : nextAlarmTime;
  }

  /// Every alarm time between [startTime] and [endTime], inclusive of the start.
  List<DateTime> getAllAlarmTimes() {
    final step = interval;
    final alarmTimes = <DateTime>[startTime];

    var nextAlarm = startTime.add(step);
    while (!nextAlarm.isAfter(endTime)) {
      alarmTimes.add(nextAlarm);
      nextAlarm = nextAlarm.add(step);
    }

    return alarmTimes;
  }

  int get totalAlarms => getAllAlarmTimes().length;

  /// 'Every hour', 'Every 30 minutes', …
  String get intervalString => intervalType.everyLabel(intervalValue);
}
