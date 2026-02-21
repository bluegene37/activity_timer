import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'alarm_sound.dart';

part 'interval_timer.g.dart';

// Update the IntervalType enum to include Hive annotations
@HiveType(typeId: 4)
enum IntervalType {
  @HiveField(0)
  hour,
  @HiveField(1)
  minute,
  @HiveField(2)
  second
}

@HiveType(typeId: 3)
class IntervalTimer extends HiveObject {
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
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now(),
    alarmSoundName = alarmSoundName ?? AlarmSound.beep.name;
    
  // Get the alarm sound
  AlarmSound get alarmSound => AlarmSound.fromString(alarmSoundName);
  
  // Set the alarm sound
  void setAlarmSound(AlarmSound sound) {
    alarmSoundName = sound.name;
  }

  // Calculate the next alarm time from a given reference time
  DateTime getNextAlarmTime(DateTime referenceTime) {
    // If reference time is before start time, first alarm is at start time
    if (referenceTime.isBefore(startTime)) {
      return startTime;
    }
    
    // If reference time is after end time, there is no next alarm
    if (referenceTime.isAfter(endTime)) {
      return endTime;
    }
    
    // Calculate time difference from start time to reference time
    final difference = referenceTime.difference(startTime);
    
    // Calculate how many intervals have passed
    int intervalInSeconds;
    switch (intervalType) {
      case IntervalType.hour:
        intervalInSeconds = intervalValue * 3600;
        break;
      case IntervalType.minute:
        intervalInSeconds = intervalValue * 60;
        break;
      case IntervalType.second:
        intervalInSeconds = intervalValue;
        break;
    }
    
    final passedIntervals = difference.inSeconds ~/ intervalInSeconds;
    
    // Calculate the next interval
    final nextIntervalSeconds = (passedIntervals + 1) * intervalInSeconds;
    final nextAlarmTime = startTime.add(Duration(seconds: nextIntervalSeconds));
    
    // If next alarm time is after end time, return end time
    if (nextAlarmTime.isAfter(endTime)) {
      return endTime;
    }
    
    return nextAlarmTime;
  }

  // Get all alarm times between start and end
  List<DateTime> getAllAlarmTimes() {
    final alarmTimes = <DateTime>[];
    
    // Add start time as the first alarm
    alarmTimes.add(startTime);
    
    DateTime currentTime = startTime;
    
    while (true) {
      // Calculate next alarm time
      DateTime nextAlarm;
      
      switch (intervalType) {
        case IntervalType.hour:
          nextAlarm = currentTime.add(Duration(hours: intervalValue));
          break;
        case IntervalType.minute:
          nextAlarm = currentTime.add(Duration(minutes: intervalValue));
          break;
        case IntervalType.second:
          nextAlarm = currentTime.add(Duration(seconds: intervalValue));
          break;
      }
      
      // If next alarm is after end time, break
      if (nextAlarm.isAfter(endTime)) {
        break;
      }
      
      // Add next alarm to the list
      alarmTimes.add(nextAlarm);
      
      // Update current time
      currentTime = nextAlarm;
    }
    
    return alarmTimes;
  }

  // Get the total number of alarms
  int get totalAlarms {
    final alarmTimes = getAllAlarmTimes();
    return alarmTimes.length;
  }

  // Get the formatted interval string
  String get intervalString {
    switch (intervalType) {
      case IntervalType.hour:
        return intervalValue == 1 
            ? 'Every hour' 
            : 'Every $intervalValue hours';
      case IntervalType.minute:
        return intervalValue == 1 
            ? 'Every minute' 
            : 'Every $intervalValue minutes';
      case IntervalType.second:
        return intervalValue == 1 
            ? 'Every second' 
            : 'Every $intervalValue seconds';
    }
  }
}
