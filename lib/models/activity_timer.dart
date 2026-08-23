import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'alarm_sound.dart';
import 'interval_phase.dart';

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

  @HiveField(5)
  IntervalPhase phase;

  ActivityTimer({
    String? id,
    required this.name,
    required this.durationInSeconds,
    this.description,
    this.alarmSoundName,
    this.phase = IntervalPhase.work,
  }) : id = id ?? const Uuid().v4();

  AlarmSound? get alarmSound =>
      alarmSoundName != null ? AlarmSound.fromString(alarmSoundName!) : null;

  void setAlarmSound(AlarmSound? sound) {
    alarmSoundName = sound?.name;
  }

  bool get isWork => phase == IntervalPhase.work;
  bool get isRest => phase == IntervalPhase.rest;
  bool get isPrepare => phase == IntervalPhase.prepare;
  bool get isCooldown => phase == IntervalPhase.cooldown;

  // Create a copy with updated fields
  ActivityTimer copyWith({
    String? name,
    int? durationInSeconds,
    String? description,
    String? alarmSoundName,
    IntervalPhase? phase,
  }) {
    return ActivityTimer(
      id: id,
      name: name ?? this.name,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      description: description ?? this.description,
      alarmSoundName: alarmSoundName ?? this.alarmSoundName,
      phase: phase ?? this.phase,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationInSeconds': durationInSeconds,
      'description': description,
      'alarmSoundName': alarmSoundName,
      'phase': phase.name,
    };
  }

  factory ActivityTimer.fromJson(Map<String, dynamic> json) {
    return ActivityTimer(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Timer',
      durationInSeconds: json['durationInSeconds'] as int? ?? 30,
      description: json['description'] as String?,
      alarmSoundName: json['alarmSoundName'] as String?,
      phase: IntervalPhase.fromString(json['phase'] as String?),
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

  @HiveField(7)
  String category; // 'fitness', 'work', 'custom'

  @HiveField(8)
  int preparationSeconds; // 0, 3, 5, 10 seconds lead-in

  TimerSequence({
    String? id,
    required this.name,
    required this.timers,
    this.defaultLoopEnabled = false,
    this.description,
    this.category = 'custom',
    this.preparationSeconds = 5,
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

  TimerSequence copyWith({
    String? name,
    List<ActivityTimer>? timers,
    bool? defaultLoopEnabled,
    String? description,
    String? category,
    int? preparationSeconds,
  }) {
    return TimerSequence(
      id: id,
      name: name ?? this.name,
      timers: timers ?? this.timers.map((t) => t.copyWith()).toList(),
      defaultLoopEnabled: defaultLoopEnabled ?? this.defaultLoopEnabled,
      description: description ?? this.description,
      category: category ?? this.category,
      preparationSeconds: preparationSeconds ?? this.preparationSeconds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'defaultLoopEnabled': defaultLoopEnabled,
      'category': category,
      'preparationSeconds': preparationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'timers': timers.map((t) => t.toJson()).toList(),
    };
  }

  factory TimerSequence.fromJson(Map<String, dynamic> json) {
    return TimerSequence(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Routine',
      description: json['description'] as String?,
      defaultLoopEnabled: json['defaultLoopEnabled'] as bool? ?? false,
      category: json['category'] as String? ?? 'custom',
      preparationSeconds: json['preparationSeconds'] as int? ?? 5,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      timers: (json['timers'] as List<dynamic>?)
              ?.map((t) => ActivityTimer.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
