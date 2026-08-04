import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'alarm_sound.dart';

part 'activity_timer.g.dart';

@HiveType(typeId: 1)
class ActivityTimer extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int durationInSeconds;

  @HiveField(3)
  String? description;

  @HiveField(4)
  String? alarmSoundName;

  ActivityTimer({
    String? id,
    required this.name,
    required this.durationInSeconds,
    this.description,
    this.alarmSoundName,
  }) : id = id ?? const Uuid().v4();

  AlarmSound? get alarmSound =>
      alarmSoundName != null ? AlarmSound.fromString(alarmSoundName!) : null;

  void setAlarmSound(AlarmSound? sound) {
    alarmSoundName = sound?.name;
  }

  // Create a copy with updated fields
  ActivityTimer copyWith({
    String? name,
    int? durationInSeconds,
    String? description,
    String? alarmSoundName,
  }) {
    return ActivityTimer(
      id: id,
      name: name ?? this.name,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      description: description ?? this.description,
      alarmSoundName: alarmSoundName ?? this.alarmSoundName,
    );
  }
}

@HiveType(typeId: 2)
class TimerSequence extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<ActivityTimer> timers;

  @HiveField(3)
  bool defaultLoopEnabled;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  String? description;

  TimerSequence({
    String? id,
    required this.name,
    required this.timers,
    this.defaultLoopEnabled = false,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  // Calculate total duration
  int get totalDuration {
    return timers.fold(0, (sum, timer) => sum + timer.durationInSeconds);
  }
}
