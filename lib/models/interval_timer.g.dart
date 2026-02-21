// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interval_timer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntervalTimerAdapter extends TypeAdapter<IntervalTimer> {
  @override
  final typeId = 3;

  @override
  IntervalTimer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IntervalTimer(
      id: fields[0] as String?,
      name: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime,
      intervalValue: (fields[4] as num).toInt(),
      intervalType: fields[5] as IntervalType,
      isActive: fields[6] == null ? false : fields[6] as bool,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      alarmSoundName: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IntervalTimer obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.intervalValue)
      ..writeByte(5)
      ..write(obj.intervalType)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.alarmSoundName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntervalTimerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IntervalTypeAdapter extends TypeAdapter<IntervalType> {
  @override
  final typeId = 4;

  @override
  IntervalType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IntervalType.hour;
      case 1:
        return IntervalType.minute;
      case 2:
        return IntervalType.second;
      default:
        return IntervalType.hour;
    }
  }

  @override
  void write(BinaryWriter writer, IntervalType obj) {
    switch (obj) {
      case IntervalType.hour:
        writer.writeByte(0);
      case IntervalType.minute:
        writer.writeByte(1);
      case IntervalType.second:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntervalTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
