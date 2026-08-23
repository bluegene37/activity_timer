import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'alarm_sound.dart';
import 'interval_phase.dart';

part 'activity_timer.g.dart';

@HiveType(typeId: 1)
class ActivityTimer extends HiveObject {
  ActivityTimer({
    String? id,
    required this.name,
    required this.durationInSeconds,
    this.description,
    this.alarmSoundName,
    this.phase = IntervalPhase.work,
  }) : id = id ?? const Uuid().v4();

  factory ActivityTimer.fromJson(Map<String, dynamic> json) => ActivityTimer(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Timer',
    durationInSeconds: json['durationInSeconds'] as int? ?? 30,
    description: json['description'] as String?,
    alarmSoundName: json['alarmSoundName'] as String?,
    phase: IntervalPhase.fromString(json['phase'] as String?),
  );

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

  AlarmSound? get alarmSound {
    final name = alarmSoundName;
    return name == null ? null : AlarmSound.fromString(name);
  }

  void setAlarmSound(AlarmSound? sound) {
    alarmSoundName = sound?.name;
  }

  bool get isWork => phase == IntervalPhase.work;
  bool get isRest => phase == IntervalPhase.rest;
  bool get isPrepare => phase == IntervalPhase.prepare;
  bool get isCooldown => phase == IntervalPhase.cooldown;

  ActivityTimer copyWith({
    String? name,
    int? durationInSeconds,
    String? description,
    String? alarmSoundName,
    IntervalPhase? phase,
  }) => ActivityTimer(
    id: id,
    name: name ?? this.name,
    durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    description: description ?? this.description,
    alarmSoundName: alarmSoundName ?? this.alarmSoundName,
    phase: phase ?? this.phase,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationInSeconds': durationInSeconds,
    'description': description,
    'alarmSoundName': alarmSoundName,
    'phase': phase.name,
  };
}

@HiveType(typeId: 2)
class TimerSequence extends HiveObject {
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
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory TimerSequence.fromJson(Map<String, dynamic> json) => TimerSequence(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Routine',
    description: json['description'] as String?,
    defaultLoopEnabled: json['defaultLoopEnabled'] as bool? ?? false,
    category: json['category'] as String? ?? 'custom',
    preparationSeconds: json['preparationSeconds'] as int? ?? 5,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    timers: [
      for (final timer in json['timers'] as List<dynamic>? ?? const [])
        ActivityTimer.fromJson(timer as Map<String, dynamic>),
    ],
  );

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

  /// Combined length of every step, ignoring loops and the lead-in.
  int get totalDuration =>
      timers.fold(0, (sum, timer) => sum + timer.durationInSeconds);

  TimerSequence copyWith({
    String? name,
    List<ActivityTimer>? timers,
    bool? defaultLoopEnabled,
    String? description,
    String? category,
    int? preparationSeconds,
  }) => TimerSequence(
    id: id,
    name: name ?? this.name,
    timers: timers ?? [for (final timer in this.timers) timer.copyWith()],
    defaultLoopEnabled: defaultLoopEnabled ?? this.defaultLoopEnabled,
    description: description ?? this.description,
    category: category ?? this.category,
    preparationSeconds: preparationSeconds ?? this.preparationSeconds,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'defaultLoopEnabled': defaultLoopEnabled,
    'category': category,
    'preparationSeconds': preparationSeconds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'timers': [for (final timer in timers) timer.toJson()],
  };
}
