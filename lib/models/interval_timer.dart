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

  // Gene - Oct, 06, 2026: Added shortUnit and shortEveryLabel to support compact tags (e.g. 'Every 15 min').
  String get shortUnit {
    switch (this) {
      case IntervalType.hour:
        return 'hr';
      case IntervalType.minute:
        return 'min';
      case IntervalType.second:
        return 'sec';
    }
  }

  /// 'Every 1 hr', 'Every 2 hr', 'Every 15 min', 'Every 30 sec'.
  String shortEveryLabel(int value) => 'Every $value $shortUnit';
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

  // Gene - Nov, 7, 2026: Added JSON serialization helpers so active interval sessions can be persisted and restored even if not yet stored in the interval timers box.
  factory IntervalTimer.fromJson(Map<String, dynamic> json) => IntervalTimer(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Interval Timer',
    startTime:
        DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
    endTime:
        DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
    intervalValue: json['intervalValue'] as int? ?? 1,
    intervalType: IntervalType.values.firstWhere(
      (t) => t.name == json['intervalType'],
      orElse: () => IntervalType.hour,
    ),
    isActive: json['isActive'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    alarmSoundName: json['alarmSoundName'] as String?,
  );

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

  // Gene - Oct, 06, 2026: Added shortIntervalString for compact badge representations like 'Every 15 min'.
  /// 'Every 1 hr', 'Every 15 min', …
  String get shortIntervalString => intervalType.shortEveryLabel(intervalValue);

  // Gene - Nov, 7, 2026: Added JSON serialization helpers so active interval sessions can be persisted and restored even if not yet stored in the interval timers box.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'intervalValue': intervalValue,
    'intervalType': intervalType.name,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'alarmSoundName': alarmSoundName,
  };
}
