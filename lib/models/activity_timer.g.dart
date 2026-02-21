// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_timer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActivityTimerAdapter extends TypeAdapter<ActivityTimer> {
  @override
  final typeId = 1;

  @override
  ActivityTimer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityTimer(
      id: fields[0] as String?,
      name: fields[1] as String,
      durationInSeconds: (fields[2] as num).toInt(),
      description: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityTimer obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.durationInSeconds)
      ..writeByte(3)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityTimerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimerSequenceAdapter extends TypeAdapter<TimerSequence> {
  @override
  final typeId = 2;

  @override
  TimerSequence read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimerSequence(
      id: fields[0] as String?,
      name: fields[1] as String,
      timers: (fields[2] as List).cast<ActivityTimer>(),
      defaultLoopEnabled: fields[3] == null ? false : fields[3] as bool,
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TimerSequence obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.timers)
      ..writeByte(3)
      ..write(obj.defaultLoopEnabled)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSequenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
